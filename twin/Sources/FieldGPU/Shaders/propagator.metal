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

// ---------------------------------------------------------------------------
// Port fields for any preset: the gate-granular operator with per-element
// complex coupling (horn transfer x weight), axial wall images and air
// absorption. Mirrors FieldCore.Propagator.init term for term; gate G-GPU-FS
// holds the two together. One thread per field point; points are explicit so
// the same kernel serves whole lattices and local probe lattices.

struct ElementPF {
    float4 position;      // xyz, w unused
    float4 normal;        // xyz, w unused
    float  area;
    float  equivalentRadius;
    float2 coupling;      // complex coupling, weight folded in
    int    gateIndex;
    int    monopole;      // 1 = omnidirectional
    int    _pad0, _pad1;
};

struct PFParams {
    uint   pointCount;
    uint   elementCount;
    uint   gateCount;
    int    order;          // image orders per direction (0 = free field)
    float  k;              // wavenumber
    float  prefactorMag;   // rho0 * c0 * k / (2 pi)
    float  alpha;          // amplitude absorption, Np/m
    float  capSeparation;  // metres; 0 disables the walls
    float  reflection;     // per-bounce pressure reflection
    float  _pad0, _pad1, _pad2;
};

kernel void buildPortFields(device float2*            H        [[buffer(0)]],
                            device const ElementPF*   elements [[buffer(1)]],
                            device const float4*      points   [[buffer(2)]],
                            constant PFParams&        P        [[buffer(3)]],
                            uint                      gid      [[thread_position_in_grid]])
{
    if (gid >= P.pointCount) return;
    float3 x = points[gid].xyz;
    float2 acc[64];
    uint nG = min(P.gateCount, 64u);
    for (uint g = 0; g < nG; ++g) acc[g] = float2(0.0f);
    bool walls = P.capSeparation > 0.0f && P.order > 0;
    float L = P.capSeparation;

    for (uint e = 0; e < P.elementCount; ++e) {
        ElementPF el = elements[e];
        if (el.gateIndex < 0 || uint(el.gateIndex) >= nG) continue;
        float z0 = el.position.z;
        float2 sum = float2(0.0f);
        int nImg = walls ? 1 + 2 * P.order : 1;
        for (int im = 0; im < nImg; ++im) {
            // image 0 = direct; then for m = 1..order two images of weight R^m
            float zi = z0, w = 1.0f;
            if (im > 0) {
                int m = (im + 1) / 2;
                bool first = (im % 2) == 1;
                w = pow(P.reflection, float(m));
                if (m % 2 == 0) zi = first ? z0 + float(m) * L : z0 - float(m) * L;
                else            zi = first ? -z0 + float(1 + m) * L : -z0 + float(1 - m) * L;
            }
            float3 d = x - float3(el.position.x, el.position.y, zi);
            float r = max(length(d), 1e-9f);
            float cosTheta = fabs(dot(d, el.normal.xyz)) / r;
            float dir = el.monopole == 1 ? 1.0f : directivity(P.k, el.equivalentRadius, cosTheta);
            float amp = P.prefactorMag * el.area * dir * w * exp(-P.alpha * r) / r;
            float c; float s = sincos(P.k * r, c);
            sum += float2(-s, c) * amp;               // i * e^{ikr} * amp
        }
        float2 cp = el.coupling;
        acc[el.gateIndex] += float2(sum.x * cp.x - sum.y * cp.y, sum.x * cp.y + sum.y * cp.x);
    }
    uint base = gid * P.gateCount;
    for (uint g = 0; g < nG; ++g) H[base + g] = acc[g];
}
