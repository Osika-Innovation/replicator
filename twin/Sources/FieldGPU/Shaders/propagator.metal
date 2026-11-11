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

// Bessel J0 — Numerical Recipes bessj0, the same family as besselJ1.
inline float besselJ0(float x) {
    float ax = fabs(x);
    if (ax < 8.0f) {
        float y = x * x;
        float a1 = 57568490574.0f + y * (-13362590354.0f + y * (651619640.7f
                 + y * (-11214424.18f + y * (77392.33017f + y * (-184.9052456f)))));
        float a2 = 57568490411.0f + y * (1029532985.0f + y * (9494680.718f
                 + y * (59272.64853f + y * (267.8532712f + y))));
        return a1 / a2;
    }
    float z = 8.0f / ax, y = z * z, xx = ax - 0.785398164f;
    float a1 = 1.0f + y * (-0.1098628627e-2f + y * (0.2734510407e-4f
             + y * (-0.2073370639e-5f + y * 0.2093887211e-6f)));
    float a2 = -0.1562499995e-1f + y * (0.1430488765e-3f
             + y * (-0.6911147651e-5f + y * (0.7621095161e-6f - y * 0.934935152e-7f)));
    return sqrt(0.636619772f / ax) * (cos(xx) * a1 - z * sin(xx) * a2);
}

// Directivity and its slope dD/d(cos θ) — mirrors
// Propagator.pistonDirectivityAndSlope.
inline float2 directivityAndSlope(float k, float a, float c) {
    float ka = k * a;
    if (ka < 0.5f) return float2(c, 1.0f);
    float s2 = max(0.0f, 1.0f - c * c);
    float x = ka * sqrt(s2);
    if (x < 1e-3f) return float2(1.0f - x * x / 8.0f, ka * ka * c / 4.0f);
    float j1 = besselJ1(x), j2 = 2.0f * j1 / x - besselJ0(x);
    return float2(2.0f * j1 / x, 2.0f * j2 * c / s2);
}

inline float directivity(float k, float a, float cosTheta) {
    float ka = k * a;
    if (ka < 0.5f) return cosTheta;
    float sinTheta = sqrt(max(0.0f, 1.0f - cosTheta * cosTheta));
    float x = ka * sinTheta;
    if (x < 1e-6f) return 1.0f;
    return 2.0f * besselJ1(x) / x;
}

// One element as the array kernels read it.
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
