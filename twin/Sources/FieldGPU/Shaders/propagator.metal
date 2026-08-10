#include <metal_stdlib>
using namespace metal;

// T0 — Rayleigh–Sommerfeld propagator, gate-granular (§11).
// Mirrors FieldCore.Propagator exactly; the CPU version is the reference the
// gate compares against.

struct ElementGPU {
    float3 position;
    float3 normal;
    float  area;
    float  equivalentRadius;
    int    gateIndex;
    int    _pad;
};

struct PropParams {
    float3 origin;
    float  spacing;
    uint   nx, ny, nz;
    uint   elementCount;
    uint   gateCount;
    float  k;             // wavenumber
    float  prefactorMag;  // rho0 * c0 * k / (2 pi)
    float  _pad;
};

// Bessel J1 — Abramowitz & Stegun 9.4.4/9.4.6, same rational forms as the
// Swift reference so the two paths agree to float precision.
inline float besselJ1(float x) {
    float ax = fabs(x);
    if (ax < 8.0f) {
        float y = x * x;
        float p1 = x * (72362614232.0f + y * (-7895059235.0f + y * (242396853.1f
                 + y * (-2972611.439f + y * (15704.48260f + y * (-30.16036606f))))));
        float p2 = 144725228442.0f + y * (2300535178.0f + y * (18583304.74f
                 + y * (99447.43394f + y * (376.9991397f + y))));
        return p1 / p2;
    }
    float z = 8.0f / ax;
    float y = z * z;
    float xx = ax - 2.356194491f;
    float p1 = 1.0f + y * (0.183105e-2f + y * (-0.3516396496e-4f
             + y * (0.2457520174e-5f + y * (-0.240337019e-6f))));
    float p2 = 0.04687499995f + y * (-0.2002690873e-3f
             + y * (0.8449199096e-5f + y * (-0.88228987e-6f + y * 0.105787412e-6f)));
    float ans = sqrt(0.636619772f / ax) * (cos(xx) * p1 - z * sin(xx) * p2);
    return x < 0.0f ? -ans : ans;
}

inline float directivity(float k, float a, float cosTheta) {
    float ka = k * a;
    if (ka < 0.5f) return cosTheta;
    float sinTheta = sqrt(max(0.0f, 1.0f - cosTheta * cosTheta));
    float x = ka * sinTheta;
    if (x < 1e-6f) return 1.0f;
    return 2.0f * besselJ1(x) / x;
}

// Build one row of H (all gates) for one field point.
kernel void buildH(device float2*             H        [[buffer(0)]],
                   device const ElementGPU*   elements [[buffer(1)]],
                   constant PropParams&       P        [[buffer(2)]],
                   uint                       gid      [[thread_position_in_grid]])
{
    uint total = P.nx * P.ny * P.nz;
    if (gid >= total) return;

    uint i = gid % P.nx;
    uint j = (gid / P.nx) % P.ny;
    uint kk = gid / (P.nx * P.ny);
    float3 x = P.origin + float3(float(i), float(j), float(kk)) * P.spacing;

    uint base = gid * P.gateCount;
    for (uint g = 0; g < P.gateCount; ++g) H[base + g] = float2(0.0f, 0.0f);

    for (uint e = 0; e < P.elementCount; ++e) {
        ElementGPU el = elements[e];
        if (el.gateIndex < 0 || uint(el.gateIndex) >= P.gateCount) continue;
        float3 d = x - el.position;
        float r = max(length(d), 1e-9f);
        float cosTheta = fabs(dot(d, el.normal)) / r;
        float dir = directivity(P.k, el.equivalentRadius, cosTheta);
        float amp = P.prefactorMag * el.area * dir / r;
        float kr = P.k * r;
        // i * e^{i kr} * amp  =  amp * (-sin(kr) + i cos(kr))
        float2 contrib = float2(-sin(kr), cos(kr)) * amp;
        H[base + uint(el.gateIndex)] += contrib;
    }
}

// p = H u, one field point per thread.
kernel void forward(device const float2* H     [[buffer(0)]],
                    device const float2* u     [[buffer(1)]],
                    device float2*       out   [[buffer(2)]],
                    constant PropParams& P     [[buffer(3)]],
                    uint                 gid   [[thread_position_in_grid]])
{
    uint total = P.nx * P.ny * P.nz;
    if (gid >= total) return;
    uint base = gid * P.gateCount;
    float2 acc = float2(0.0f, 0.0f);
    for (uint g = 0; g < P.gateCount; ++g) {
        float2 h = H[base + g];
        float2 d = u[g];
        acc += float2(h.x * d.x - h.y * d.y, h.x * d.y + h.y * d.x);
    }
    out[gid] = acc;
}

// |p| magnitude, for the field-slice overlay. Writes straight into the texture
// path with no CPU readback (§8 viewport ruling).
kernel void magnitude(device const float2* field [[buffer(0)]],
                      device float*        mag   [[buffer(1)]],
                      constant uint&       count [[buffer(2)]],
                      uint                 gid   [[thread_position_in_grid]])
{
    if (gid >= count) return;
    mag[gid] = length(field[gid]);
}
