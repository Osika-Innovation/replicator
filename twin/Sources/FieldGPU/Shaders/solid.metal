#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Shaded solids for the CAD model (RSW-1 `fieldc cad render`, Machine tab).
//
// One pipeline, three tricks that make a cutaway read as engineering rather
// than as a mesh with a hole in it:
//   1. The section cut is a fragment discard (a wedge in azimuth, optionally
//      a height band), so any cut is live — no mesh booleans.
//   2. Back faces seen through the cut are painted as SECTION CAPS: flat,
//      hatched, tinted by the part's own material. A closed solid's back
//      faces are exactly its interior, so this is what a sawn part looks like.
//   3. Transparent materials never cap; glass stays glass when cut.
// ---------------------------------------------------------------------------

struct SolidUniforms {
    float4x4 mvp;
    float4   eye;          // xyz = camera position (m)
    float4   keyDir;       // toward the key light
    float4   fillDir;      // toward the fill light
    float4   cut;          // x = on, y = a0 (rad), z = a1 (rad), w = zMax (m; 0 = none)
    float4   cutAxis;      // xy = axis centre (m), z = zMin (m), w = hatch spacing (m)
    float4   ambTop;
    float4   ambBottom;
    float4   capTint;      // rgb multiply for caps, a = hatch strength
};

struct SolidOut {
    float4 position [[position]];
    float3 world;
    float3 normal;
    float4 color;
    float4 material;       // x = specular, y = shininess, z = emission, w = flags
};

vertex SolidOut solidVertex(uint vid [[vertex_id]],
                            device const float3* pos  [[buffer(0)]],
                            device const float3* nor  [[buffer(1)]],
                            device const float4* col  [[buffer(2)]],
                            device const float4* mat  [[buffer(3)]],
                            constant SolidUniforms& U [[buffer(4)]])
{
    SolidOut o;
    o.world = pos[vid];
    o.position = U.mvp * float4(pos[vid], 1.0);
    o.normal = nor[vid];
    o.color = col[vid];
    o.material = mat[vid];
    return o;
}

inline bool insideCut(float3 p, constant SolidUniforms& U) {
    if (U.cut.x < 0.5) return false;
    float2 q = p.xy - U.cutAxis.xy;
    float a = atan2(q.y, q.x);
    float a0 = U.cut.y, a1 = U.cut.z;
    bool inWedge = (a0 <= a1) ? (a >= a0 && a <= a1) : (a >= a0 || a <= a1);
    if (!inWedge) return false;
    if (U.cut.w > 0.0 && (p.z > U.cut.w || p.z < U.cutAxis.z)) return false;
    return true;
}

fragment float4 solidFragment(SolidOut in [[stage_in]],
                              bool front [[front_facing]],
                              constant SolidUniforms& U [[buffer(0)]])
{
    float flags = in.material.w;               // 0 opaque, 1 transparent, 2 floor
    if (flags < 1.5 && insideCut(in.world, U)) discard_fragment();
    float3 base = in.color.rgb;

    if (flags > 1.5) {
        // Studio floor: soft radial falloff plus a contact shadow at the foot.
        float r = length(in.world.xy);
        float fade = smoothstep(1.6, 0.35, r);
        float shadow = 1.0 - 0.38 * smoothstep(0.62, 0.18, r);
        return float4(base * shadow, in.color.a * fade);
    }

    if (!front && flags < 0.5) {
        // Section cap: flat, hatched at 45°, tinted by the material.
        float s = max(U.cutAxis.w, 1e-4);
        float h = fract((in.world.x + in.world.y + in.world.z) / s);
        float line = smoothstep(0.0, 0.08, h) * smoothstep(0.30, 0.22, h);
        float3 c = base * U.capTint.rgb;
        c = mix(c, c * 0.55, line * U.capTint.a);
        return float4(c, 1.0);
    }

    float3 n = normalize(front ? in.normal : -in.normal);
    float3 v = normalize(U.eye.xyz - in.world);
    float3 L = normalize(U.keyDir.xyz), F = normalize(U.fillDir.xyz);
    float diff = max(dot(n, L), 0.0);
    float fill = max(dot(n, F), 0.0) * 0.35;
    float hemi = n.z * 0.5 + 0.5;
    float3 amb = mix(U.ambBottom.rgb, U.ambTop.rgb, hemi);
    float3 hlf = normalize(L + v);
    float spec = pow(max(dot(n, hlf), 0.0), max(in.material.y, 1.0)) * in.material.x;
    float rim = pow(1.0 - max(dot(n, v), 0.0), 3.0) * 0.22;
    float3 c = base * (amb + diff * 0.92 + fill) + spec * (0.55 + 0.45 * base) + rim * amb;
    c += base * in.material.z * 1.25;
    float alpha = in.color.a;
    if (flags > 0.5) {
        // Glass: Fresnel-ish — more opaque at grazing angles, faint face-on.
        float fr = pow(1.0 - max(dot(n, v), 0.0), 2.5);
        alpha = clamp(in.color.a + fr * 0.55 + spec * 0.6, 0.0, 0.92);
    }
    return float4(c, alpha);
}
