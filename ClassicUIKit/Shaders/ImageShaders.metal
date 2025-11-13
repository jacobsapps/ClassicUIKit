#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;

[[ stitchable ]]
float4 grainyFilter(
    coreimage::sampler src
) {
    float2 coord = src.coord();
    float4 sampleColor = sample(src, coord);
    float value = fract(sin(dot(coord / 120.0, float2(12.9898, 78.233))) * 43758.5453);
    float3 noise = float3(value, value, value) * 0.12;
    float3 damping = float3(-0.05, -0.05, -0.05);
    float3 result = clamp(sampleColor.rgb + noise + damping, 0.0f, 1.0f);
    return float4(result, sampleColor.a);
}

[[ stitchable ]]
float4 grayscaleFilter(
    coreimage::sampler src
) {
    float4 color = sample(src, src.coord());
    float luminance = dot(color.rgb, float3(0.2125, 0.7154, 0.0721));
    return float4(luminance, luminance, luminance, color.a);
}

[[ stitchable ]]
float4 spectralFilter(
    coreimage::sampler src
) {
    float4 color = sample(src, src.coord());
    float luminance = dot(color.rgb, float3(0.2125, 0.7154, 0.0721));
    float inverted = 1.0 - luminance;
    float scaled = pow(inverted, 3.0);
    return float4(scaled, scaled, scaled, color.a);
}

[[ stitchable ]]
float4 alienFilter(
    coreimage::sample_t s
) {
    return float4(s.b, s.r, s.g, s.a);
}

[[ stitchable ]]
float4 threeDGlassesShader(
    coreimage::sampler src
) {
    float4 color = sample(src, src.coord());
    float2 redCoord = src.coord() - float2(0.04, 0.04);
    color.r = sample(src, redCoord).r;
    float2 blueCoord = src.coord() + float2(0.02, 0.02);
    color.b = sample(src, blueCoord).b;
    return color * color.a;
}

[[ stitchable ]]
float2 thickGlassSquares(
    float intensity,
    coreimage::destination dest
) {
    return float2(
        dest.coord().x + (intensity * sin(dest.coord().x / 40.0)),
        dest.coord().y + (intensity * sin(dest.coord().y / 40.0))
    );
}

[[ stitchable ]]
float2 lensFilter(
    float width,
    float height,
    float centerX,
    float centerY,
    float radius,
    float intensity,
    coreimage::destination dest
) {
    float2 size = float2(width, height);
    float2 normalizedCoord = dest.coord() / size;
    float2 center = float2(centerX, centerY);
    float distanceFromCenter = distance(normalizedCoord, center);

    if (distanceFromCenter < radius) {
        float2 vectorFromCenter = normalizedCoord - center;
        float normalizedDistance = pow(distanceFromCenter / radius, 4.0);
        float distortion = tan(M_PI_2_F * normalizedDistance) * intensity;
        float2 distortedPosition = center + (vectorFromCenter * (1.0 + distortion));
        return distortedPosition * size;
    } else {
        return dest.coord();
    }
}
