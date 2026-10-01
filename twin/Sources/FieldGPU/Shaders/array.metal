// ---------------------------------------------------------------------------
// Open-air plate array (ENGINE.md): two plates of independently driven piston
// elements, imaged in the plates. Matrix-free: no rows are stored. One pass
// gives p and ∇p at any points for a drive; a second gives, for every element,
// the gradient of a weighted sum of the Gor'kov potential. The element terms
// are those of buildPortFieldsGrad (same images, directivity and its slope);
// FieldCore.Propagator.gateGradientRows with one gate per element is the
// reference (gate G-A1).

struct ArrParams {
    uint  pointCount;
    uint  elementCount;
    int   order;
    float k;
    float prefactorMag;
    float alpha;
    float capSeparation;
    float reflection;
};

// One element's p and ∇p at x, all its images summed.
inline void arrayElementField(float3 x, ElementPF el, constant ArrParams& P,
                              thread float2& s0, thread float2& sx, thread float2& sy, thread float2& sz) {
    s0 = float2(0.0f); sx = float2(0.0f); sy = float2(0.0f); sz = float2(0.0f);
    bool walls = P.capSeparation > 0.0f && P.order > 0;
    float L = P.capSeparation;
    float z0 = el.position.z;
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
        float a = -P.alpha - 1.0f / r, b = P.k;               // radial: ((ik − α) − 1/r)
        float2 dterm = float2(term.x * a - term.y * b, term.x * b + term.y * a);
        float3 u = d / r;
        float3 gc = ((dn >= 0.0f ? 1.0f : -1.0f) * el.normal.xyz - cosTheta * u) / r;
        float2 ang = base * ds.y;                              // D'(cosθ) ∇cosθ
        s0 += term;
        sx += dterm * u.x + ang * gc.x;
        sy += dterm * u.y + ang * gc.y;
        sz += dterm * u.z + ang * gc.z;
    }
}

inline float2 acmul(float2 a, float2 b) { return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x); }
// conj(a) · b
inline float2 acmulc(float2 a, float2 b) { return float2(a.x * b.x + a.y * b.y, a.x * b.y - a.y * b.x); }

// Forward: S[p·4 + c] = Σ_e G_e(x_p)[c] · drive[e], c = 0 → p, 1…3 → ∇p.
kernel void arrayForward(device float2*          S        [[buffer(0)]],
                         device const ElementPF* elements [[buffer(1)]],
                         device const float2*    drive    [[buffer(2)]],
                         device const float4*    points   [[buffer(3)]],
                         constant ArrParams&     P        [[buffer(4)]],
                         uint                    gid      [[thread_position_in_grid]])
{
    if (gid >= P.pointCount) return;
    float3 x = points[gid].xyz;
    float2 a0 = float2(0.0f), ax = float2(0.0f), ay = float2(0.0f), az = float2(0.0f);
    for (uint e = 0; e < P.elementCount; ++e) {
        float2 dv = drive[e];
        if (dv.x == 0.0f && dv.y == 0.0f) continue;
        float2 s0, sx, sy, sz;
        arrayElementField(x, elements[e], P, s0, sx, sy, sz);
        a0 += acmul(s0, dv); ax += acmul(sx, dv); ay += acmul(sy, dv); az += acmul(sz, dv);
    }
    uint b = gid * 4;
    S[b] = a0; S[b + 1] = ax; S[b + 2] = ay; S[b + 3] = az;
}

// Adjoint, one threadgroup (256 threads) per element:
// grad[e] = Σ_p conj(G_e[0]) A[p·4] − Σ_c conj(G_e[c]) A[p·4 + c], with
// A = (w·K1·p, w·K2·∂x p, w·K2·∂y p, w·K2·∂z p) per point — the same sum as
// ForceCompiler.adjoint.
kernel void arrayAdjoint(device float2*          grad     [[buffer(0)]],
                         device const ElementPF* elements [[buffer(1)]],
                         device const float2*    A        [[buffer(2)]],
                         device const float4*    points   [[buffer(3)]],
                         constant ArrParams&     P        [[buffer(4)]],
                         uint                    tg       [[threadgroup_position_in_grid]],
                         uint                    tid      [[thread_index_in_threadgroup]])
{
    threadgroup float2 sh[256];
    float2 acc = float2(0.0f);
    if (tg < P.elementCount) {
        ElementPF el = elements[tg];
        for (uint p = tid; p < P.pointCount; p += 256) {
            float2 s0, sx, sy, sz;
            arrayElementField(points[p].xyz, el, P, s0, sx, sy, sz);
            uint b = p * 4;
            acc += acmulc(s0, A[b]) - acmulc(sx, A[b + 1]) - acmulc(sy, A[b + 2]) - acmulc(sz, A[b + 3]);
        }
    }
    sh[tid] = acc;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint s = 128; s > 0; s >>= 1) {
        if (tid < s) sh[tid] += sh[tid + s];
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (tid == 0 && tg < P.elementCount) grad[tg] = sh[0];
}
