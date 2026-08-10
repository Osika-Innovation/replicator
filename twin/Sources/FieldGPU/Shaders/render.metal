#include <metal_stdlib>
using namespace metal;

struct SceneUniforms {
    float4x4 mvp;
    float4   tint;
    float    pointSize;
    float    _pad0, _pad1, _pad2;
};

struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color    [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float  pointSize [[point_size]];
};

vertex VertexOut sceneVertex(uint vid [[vertex_id]],
                             device const float3*  positions [[buffer(0)]],
                             device const float4*  colors    [[buffer(1)]],
                             constant SceneUniforms& U       [[buffer(2)]])
{
    VertexOut o;
    o.position = U.mvp * float4(positions[vid], 1.0);
    o.color = colors[vid] * U.tint;
    o.pointSize = U.pointSize;
    return o;
}

fragment float4 sceneFragment(VertexOut in [[stage_in]]) {
    return in.color;
}

// ---------------------------------------------------------------------------
// Field slice: sample |p| on a plane and colour it. Reads the SAME buffer the
// compute pass wrote — one buffer, two shaders, zero readback (§8).
// ---------------------------------------------------------------------------

struct SliceUniforms {
    float4x4 mvp;
    uint     nx, ny, nz;
    uint     axis;        // 0 = x, 1 = y, 2 = z
    uint     slice;       // index along that axis
    float    scale;       // log-compression reference
    float    _pad0, _pad1;
};

struct SliceOut {
    float4 position [[position]];
    float2 uv;
};

vertex SliceOut sliceVertex(uint vid [[vertex_id]],
                            device const float3*  corners [[buffer(0)]],
                            constant SliceUniforms& U     [[buffer(1)]])
{
    SliceOut o;
    o.position = U.mvp * float4(corners[vid], 1.0);
    // Two triangles, 6 verts: 0,1,2, 0,2,3
    const float2 uvs[6] = { float2(0,0), float2(1,0), float2(1,1),
                            float2(0,0), float2(1,1), float2(0,1) };
    o.uv = uvs[vid % 6];
    return o;
}

// Perceptually-ordered magnitude ramp. Deliberately NOT phase-as-hue: hue does
// not survive alpha compositing (spec §16.3), so amplitude gets the ramp.
inline float3 magnitudeRamp(float t) {
    t = clamp(t, 0.0f, 1.0f);
    float3 c0 = float3(0.02f, 0.03f, 0.09f);   // near-silence
    float3 c1 = float3(0.10f, 0.25f, 0.55f);
    float3 c2 = float3(0.20f, 0.65f, 0.70f);
    float3 c3 = float3(0.95f, 0.75f, 0.30f);
    float3 c4 = float3(1.00f, 0.98f, 0.90f);   // antinode
    if (t < 0.25f) return mix(c0, c1, t / 0.25f);
    if (t < 0.50f) return mix(c1, c2, (t - 0.25f) / 0.25f);
    if (t < 0.75f) return mix(c2, c3, (t - 0.50f) / 0.25f);
    return mix(c3, c4, (t - 0.75f) / 0.25f);
}

fragment float4 sliceFragment(SliceOut in [[stage_in]],
                              device const float2*  field [[buffer(0)]],
                              constant SliceUniforms& U   [[buffer(1)]])
{
    uint a, b, idx;
    if (U.axis == 2) {
        a = uint(clamp(in.uv.x, 0.0f, 0.999f) * float(U.nx));
        b = uint(clamp(in.uv.y, 0.0f, 0.999f) * float(U.ny));
        idx = (U.slice * U.ny + b) * U.nx + a;
    } else if (U.axis == 1) {
        a = uint(clamp(in.uv.x, 0.0f, 0.999f) * float(U.nx));
        b = uint(clamp(in.uv.y, 0.0f, 0.999f) * float(U.nz));
        idx = (b * U.ny + U.slice) * U.nx + a;
    } else {
        a = uint(clamp(in.uv.x, 0.0f, 0.999f) * float(U.ny));
        b = uint(clamp(in.uv.y, 0.0f, 0.999f) * float(U.nz));
        idx = (b * U.ny + a) * U.nx + U.slice;
    }
    float mag = length(field[idx]);
    // Log compression: the dynamic range between a node and an antinode is
    // enormous and a linear ramp shows only the antinode.
    float t = log(1.0f + mag / max(U.scale, 1e-30f)) / log(11.0f);
    return float4(magnitudeRamp(t), 0.85f);
}
