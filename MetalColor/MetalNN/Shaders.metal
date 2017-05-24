//
//  Shaders.metal
//  MetalColor
//
//  Created by Ruoyu Fu on 20/5/2017.
//  Copyright © 2017 Ruoyu. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


kernel void adjustVGG(
                      texture2d<half, access::read> inTexture [[texture(0)]],
                      texture2d<half, access::write> outTexture [[texture(1)]],
                      uint2 gid [[thread_position_in_grid]])
{
    half4 inColor = inTexture.read(gid) * 255;
    half4 outColor = half4(inColor.x - 103.939, inColor.y - 116.779, inColor.z - 123.68, 0.0h);
    outTexture.write(outColor, gid);
}

kernel void batch_normal_rgba(
                              texture2d<half, access::read> inTexture [[texture(0)]],
                              texture2d<half, access::write> outTexture [[texture(1)]],
                              constant float4*                 beta      [[ buffer(0) ]],
                              constant float4*                 gamma      [[ buffer(1) ]],
                              constant float4*                 mean      [[ buffer(2) ]],
                              constant float4*                 varian      [[ buffer(3) ]],
                              ushort2 gid [[thread_position_in_grid]])
{
    float4 inColor = float4(inTexture.read(gid));
    float4 outColor = (gamma[0] * (inColor - mean[0]) / sqrt(varian[0] + 0.001)) + beta[0];

    outTexture.write(half4(outColor), gid);
    
}


kernel void batch_normal(
                         texture2d_array<half, access::read> inTexture [[texture(0)]],
                         texture2d_array<half, access::write> outTexture [[texture(1)]],
                         constant float4*                 beta      [[ buffer(0) ]],
                         constant float4*                 gamma      [[ buffer(1) ]],
                         constant float4*                 mean      [[ buffer(2) ]],
                         constant float4*                 varian      [[ buffer(3) ]],
                         ushort3 gid [[thread_position_in_grid]])
{
    float4 inColor = float4(inTexture.read(gid.xy, gid.z));
    float4 outColor = (gamma[gid.z] * (inColor - mean[gid.z]) / sqrt(varian[gid.z] + 0.001)) + beta[gid.z];

    outTexture.write(half4(outColor), gid.xy,gid.z);
}

kernel void upscaleAdd(
                       texture2d_array<half, access::read>     source  [[ texture(0) ]],
                       texture2d_array<half, access::read>     mask    [[ texture(1) ]],
                       texture2d_array<half, access::write>    dest    [[ texture(2) ]],
                       ushort3                                 gid     [[ thread_position_in_grid ]])
{
    if (gid.x >= dest.get_width() ||
        gid.y >= dest.get_height()) {
        return;
    }
    half4 source_color = source.read(gid.xy/2, gid.z);
    half4 mask_color = mask.read(gid.xy, gid.z);
    half4 result_color = source_color + mask_color;


    dest.write(result_color, gid.xy, gid.z);
}

kernel void add(
                texture2d<half, access::read>    source  [[ texture(0) ]],
                texture2d<half, access::read>    mask    [[ texture(1) ]],
                texture2d<half, access::write>   dest    [[ texture(2) ]],
                ushort2                            gid     [[ thread_position_in_grid ]])
{
    if (gid.x >= dest.get_width() ||
        gid.y >= dest.get_height()) {
        return;
    }
    half4 source_color = source.read(gid);
    half4 mask_color = mask.read(gid);
    half4 result_color = source_color + mask_color;

    dest.write(result_color, gid);
}

constexpr sampler s(coord::normalized,
                              address::clamp_to_edge,
                              filter::linear);

kernel void display(texture2d<half, access::sample> yTexture [[texture(0)]],
                    texture2d<half, access::sample> cbcrTexture [[texture(1)]],
                    texture2d<half, access::write> outTexture [[texture(2)]],
                    ushort2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() ||
        gid.y >= outTexture.get_height()) {
        return;
    }
    float texSize = float(1.0/outTexture.get_width());
    float2 pos = float2(gid) * texSize;
    if (pos.y > 1){
        return;
    }
    half y = yTexture.sample(s,pos).x;
    half2 uv = cbcrTexture.sample(s,pos).rg;

    half3 colorOffset = half3( -179.45599365/255, 135.45983887/255 , -226.81599426/255);
    half3x3 colorMatrix = half3x3(
                                  half3(1,  1, 1),
                                  half3(0.000, -.34413999, 1.77199996),
                                  half3(1.40199995, -0.71414, 0.000)
                                  );
    half3 yuv = half3(y,uv);
    half3 rgb = colorMatrix * yuv + colorOffset;

    outTexture.write(half4(rgb, 1), gid);
}

kernel void gray(
                 texture2d<half, access::read>    source  [[ texture(0) ]],
                 texture2d<half, access::write>   dest    [[ texture(1) ]],
                 ushort2                           gid     [[ thread_position_in_grid ]])
{
    if((gid.x < dest.get_width()) && (gid.y < dest.get_height()))
    {
        half4 inColor  = source.read(gid);
        half4 outColor = half4(inColor.x, inColor.x, inColor.x, inColor.x);
        dest.write(outColor, gid);
    }
}
