#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;

[[ stitchable ]]
float4 threeDGlassesShader(
    coreimage::sampler src
) {
    float4 color = sample(src, src.coord());
    float2 redCoord = src.coord() - float2(0.03, 0.03);
    color.r = sample(src, redCoord).r;
    float2 blueCoord = src.coord() + float2(0.02, 0.02);
    color.b = sample(src, blueCoord).b;
    return color * color.a;
}

[[ stitchable ]]
float4 glitchShader(
    coreimage::sampler src,
    float width,
    float height,
    float time
) {
    float2 coord = src.coord();
    float normalizedX = coord.x / width;
    float bandWidth = 0.08;
    float bandCenter = fract(time * 0.2);
    if (normalizedX > bandCenter && normalizedX < bandCenter + bandWidth) {
        float yOffset = sin((coord.x / 5.0) + (time * 25.0)) * 8.0;
        float clampedY = clamp(coord.y + yOffset, 0.0f, height - 1.0f);
        coord.y = clampedY;
    }
    return sample(src, coord);
}
