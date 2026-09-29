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
        // A source ON a plate is baffled by it already (FieldCore
        // Propagator.Walls.images): one image per order, bouncing off the far
        // plate and the near one in turn — not the between-walls pair.
        float tol = 1e-6f * max(L, 1.0f);
        bool onLower = walls && fabs(z0) < tol, onUpper = walls && fabs(z0 - L) < tol;
        bool onWall = onLower || onUpper, towardUpper = onLower;
        float zw = z0;
        int nImg = walls ? (onWall ? 1 + P.order : 1 + 2 * P.order) : 1;
        for (int im = 0; im < nImg; ++im) {
            // image 0 = direct; then for m = 1..order two images of weight R^m
            float zi = z0, w = 1.0f;
            if (im > 0 && onWall) {
                zw = towardUpper ? 2.0f * L - zw : -zw;
                towardUpper = !towardUpper;
                zi = zw; w = pow(P.reflection, float(im));
            } else if (im > 0) {
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

// Port fields WITH their analytic gradient: for every point and gate, p and
// dp/dx, dp/dy, dp/dz (layout [(point * gates + gate) * 4 + c], c = 0 is p).
// Same terms as buildPortFields; mirrors FieldCore.Propagator.gateGradientRows.
// The Gor'kov potential is a quadratic form built from exactly these rows, so
// the force compiler needs no finite differences.
kernel void buildPortFieldsGrad(device float2*            H        [[buffer(0)]],
                                device const ElementPF*   elements [[buffer(1)]],
                                device const float4*      points   [[buffer(2)]],
                                constant PFParams&        P        [[buffer(3)]],
                                uint                      gid      [[thread_position_in_grid]])
{
    if (gid >= P.pointCount) return;
    float3 x = points[gid].xyz;
    float2 acc[16][4];
    uint nG = min(P.gateCount, 16u);
    for (uint g = 0; g < nG; ++g) for (uint c = 0; c < 4; ++c) acc[g][c] = float2(0.0f);
    bool walls = P.capSeparation > 0.0f && P.order > 0;
    float L = P.capSeparation;

    for (uint e = 0; e < P.elementCount; ++e) {
        ElementPF el = elements[e];
        if (el.gateIndex < 0 || uint(el.gateIndex) >= nG) continue;
        float z0 = el.position.z;
        float2 s0 = float2(0.0f), sx = float2(0.0f), sy = float2(0.0f), sz = float2(0.0f);
        float tol = 1e-6f * max(L, 1.0f);
        bool onLower = walls && fabs(z0) < tol, onUpper = walls && fabs(z0 - L) < tol;
        bool onWall = onLower || onUpper, towardUpper = onLower;
        float zw = z0;
        int nImg = walls ? (onWall ? 1 + P.order : 1 + 2 * P.order) : 1;
        for (int im = 0; im < nImg; ++im) {
            float zi = z0, w = 1.0f;
            if (im > 0 && onWall) {
                zw = towardUpper ? 2.0f * L - zw : -zw;
                towardUpper = !towardUpper;
                zi = zw; w = pow(P.reflection, float(im));
            } else if (im > 0) {
                int m = (im + 1) / 2;
                bool first = (im % 2) == 1;
                w = pow(P.reflection, float(m));
                if (m % 2 == 0) zi = first ? z0 + float(m) * L : z0 - float(m) * L;
                else            zi = first ? -z0 + float(1 + m) * L : -z0 + float(1 - m) * L;
            }
            float3 d = x - float3(el.position.x, el.position.y, zi);
            float r = max(length(d), 1e-9f);
            float dn = dot(d, el.normal.xyz);
            float cosTheta = fabs(dn) / r;
            float2 ds = el.monopole == 1 ? float2(1.0f, 0.0f)
                                         : directivityAndSlope(P.k, el.equivalentRadius, cosTheta);
            float amp0 = P.prefactorMag * el.area * w * exp(-P.alpha * r) / r;
            float c; float s = sincos(P.k * r, c);
            float2 base = float2(-s, c) * amp0;                    // i e^{ikr} amp (no D)
            float2 term = base * ds.x;
            // radial: times ((ik - α) - 1/r) = (a + ib), a = -α - 1/r, b = k
            float a = -P.alpha - 1.0f / r, b = P.k;
            float2 dterm = float2(term.x * a - term.y * b, term.x * b + term.y * a);
            // angular: D'(cosθ) ∇cosθ, ∇cosθ = (sign(d·n) n − cosθ d̂)/r
            float3 u = d / r;
            float3 gc = ((dn >= 0.0f ? 1.0f : -1.0f) * el.normal.xyz - cosTheta * u) / r;
            float2 ang = base * ds.y;
            s0 += term;
            sx += dterm * u.x + ang * gc.x;
            sy += dterm * u.y + ang * gc.y;
            sz += dterm * u.z + ang * gc.z;
        }
        float2 cp = el.coupling;
        uint gi = uint(el.gateIndex);
        acc[gi][0] += float2(s0.x * cp.x - s0.y * cp.y, s0.x * cp.y + s0.y * cp.x);
        acc[gi][1] += float2(sx.x * cp.x - sx.y * cp.y, sx.x * cp.y + sx.y * cp.x);
        acc[gi][2] += float2(sy.x * cp.x - sy.y * cp.y, sy.x * cp.y + sy.y * cp.x);
        acc[gi][3] += float2(sz.x * cp.x - sz.y * cp.y, sz.x * cp.y + sz.y * cp.x);
    }
    uint base = gid * P.gateCount * 4;
    for (uint g = 0; g < nG; ++g) for (uint c = 0; c < 4; ++c) H[base + g * 4 + c] = acc[g][c];
}

// ---------------------------------------------------------------------------
// Cylindrical cavity (glass side wall + both plates): the modal sum of
// FieldCore.CylinderCavity.rows, one thread per point. J_|m| comes from the
// same Miller table (float, Catmull–Rom). Output per point and gate: p, or
// (p, ∂p/∂x, ∂p/∂y, ∂p/∂z) when P.withGradient == 1.

struct CavMode {
    float  gamma;     // Re μ, the radial wavenumber
    int    m;
    float2 kappa;     // axial wavenumber (Im ≥ 0)
    float2 a0;        // pre · invDen
    float2 rl;        // e^{iκL} · R_upper
    float2 r0;        // e^{iκL} · R_lower
    float2 dz;        // pre · iκ · invDen  (for ∂/∂z)
    float2 lam;       // λ = μ / Re μ  (1 on a rigid wall)
    float2 lamPow;    // λ^{|m|−1}
    float2 tfac;      // (λ² − 1)/2
    int    terms;     // multiplication-theorem terms; 0 = real argument
    int    pad;
};

struct CavParams {
    uint  pointCount;
    uint  modeCount;
    uint  gateCount;
    uint  withGradient;
    uint  tableCount;     // samples per order
    uint  tableOrders;    // orders stored (maxOrder + 2)
    float tableDx;
    float length;
};

inline float2 cmul(float2 a, float2 b) { return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x); }

inline float besselTab(device const float* T, constant CavParams& P, int m, float x) {
    uint mm = uint(abs(m));
    if (mm >= P.tableOrders) return 0.0f;            // J_m(x) ≈ 0 for m ≫ x
    float u = x / P.tableDx;
    int i = clamp(int(u), 1, int(P.tableCount) - 3);
    float t = u - float(i);
    uint b = mm * P.tableCount + uint(i);
    float p0 = T[b - 1], p1 = T[b], p2 = T[b + 1], p3 = T[b + 2];
    return p1 + 0.5f * t * (p2 - p0 + t * (2.0f * p0 - 5.0f * p1 + 4.0f * p2 - p3 + t * (3.0f * (p1 - p2) + p3 - p0)));
}

kernel void buildCavityFields(device float2*          H      [[buffer(0)]],
                              device const CavMode*   modes  [[buffer(1)]],
                              device const float2*    W      [[buffer(2)]],   // [q][W0 g…, WL g…]
                              device const float*     T      [[buffer(3)]],
                              device const float4*    points [[buffer(4)]],
                              constant CavParams&     P      [[buffer(5)]],
                              uint                    gid    [[thread_position_in_grid]])
{
    if (gid >= P.pointCount) return;
    float3 x = points[gid].xyz;
    uint G = min(P.gateCount, 16u);
    float2 acc[16][4];
    for (uint g = 0; g < G; ++g) for (uint c = 0; c < 4; ++c) acc[g][c] = float2(0.0f);
    float r = max(length(x.xy), 1e-9f);
    float phi = atan2(x.y, x.x);
    float cph = cos(phi), sph = sin(phi);
    bool grad = P.withGradient == 1;
    for (uint q = 0; q < P.modeCount; ++q) {
        CavMode md = modes[q];
        float xa = md.gamma * r;
        int am = abs(md.m);
        // Radial function J_|m|(μr) and ∂/∂r of it. On a lined wall μ is
        // complex: J_ν(λz) = λ^ν Σ_k (−t)^k/k! J_{ν+k}(z), z = Re μ · r,
        // t = (λ² − 1) z/2, off the same real table (DLMF 10.23.1).
        float2 radial, dradial = float2(0.0f);
        if (md.terms == 0) {
            radial = float2(besselTab(T, P, am, xa), 0.0f);
            if (grad) {
                float jp = (am == 0 ? -besselTab(T, P, 1, xa)
                                    : 0.5f * (besselTab(T, P, am - 1, xa) - besselTab(T, P, am + 1, xa))) * md.gamma;
                dradial = float2(jp, 0.0f);
            }
        } else {
            float2 mt = -md.tfac * xa;
            float2 ck = float2(1.0f, 0.0f), sM1 = float2(0.0f), s0 = float2(0.0f), sP1 = float2(0.0f);
            float lm1 = am == 0 ? -besselTab(T, P, 1, xa) : besselTab(T, P, am - 1, xa);
            float l0 = besselTab(T, P, am, xa), lp1 = besselTab(T, P, am + 1, xa);
            for (int k = 0; k <= md.terms; ++k) {
                sM1 += ck * lm1; s0 += ck * l0; sP1 += ck * lp1;
                ck = cmul(ck, mt) / float(k + 1);
                lm1 = l0; l0 = lp1; lp1 = besselTab(T, P, am + k + 2, xa);
            }
            float2 lm = cmul(md.lamPow, md.lam);
            radial = cmul(lm, s0);
            if (grad) {
                float2 mu = md.lam * md.gamma;
                dradial = cmul(mu, 0.5f * (cmul(md.lamPow, sM1) - cmul(cmul(lm, md.lam), sP1)));
            }
        }
        float cm, sm = sincos(float(md.m) * phi, cm);
        float2 e = float2(cm, sm);
        float2 psi = cmul(e, radial);
        // e1 = e^{iκz}, e2 = e^{iκ(L−z)}
        float2 k = md.kappa;
        float d1 = exp(-k.y * x.z), d2 = exp(-k.y * (P.length - x.z));
        float c1, s1 = sincos(k.x * x.z, c1);
        float c2, s2 = sincos(k.x * (P.length - x.z), c2);
        float2 e1 = float2(c1, s1) * d1, e2 = float2(c2, s2) * d2;
        float2 z0 = cmul(md.a0, e1 + cmul(md.rl, e2));
        float2 zl = cmul(md.a0, e2 + cmul(md.r0, e1));
        float2 dz0 = float2(0.0f), dzl = float2(0.0f), dpx = float2(0.0f), dpy = float2(0.0f);
        if (grad) {
            dz0 = cmul(md.dz, e1 - cmul(md.rl, e2));
            dzl = cmul(md.dz, cmul(md.r0, e1) - e2);
            float2 dR = cmul(e, dradial);
            float2 dPhi = float2(-psi.y, psi.x) * float(md.m);          // i m ψ
            dpx = dR * cph - dPhi * (sph / r);
            dpy = dR * sph + dPhi * (cph / r);
        }
        uint wb = q * P.gateCount * 2;
        for (uint g = 0; g < G; ++g) {
            float2 w0 = W[wb + g], wl = W[wb + P.gateCount + g];
            float2 zs = cmul(w0, z0) + cmul(wl, zl);
            acc[g][0] += cmul(psi, zs);
            if (grad) {
                acc[g][1] += cmul(dpx, zs);
                acc[g][2] += cmul(dpy, zs);
                acc[g][3] += cmul(psi, cmul(w0, dz0) + cmul(wl, dzl));
            }
        }
    }
    uint per = grad ? 4u : 1u;
    uint base = gid * P.gateCount * per;
    for (uint g = 0; g < G; ++g) for (uint c = 0; c < per; ++c) H[base + g * per + c] = acc[g][c];
}
