#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;

[[ stitchable ]]
float4 pixellateShader(
    coreimage::sampler src,
    float blockSize
) {
    float2 coord = src.coord();
    float2 pixelatedCoord = floor(coord / blockSize) * blockSize + float2(blockSize * 0.5, blockSize * 0.5);
    return sample(src, pixelatedCoord);
}

[[ stitchable ]]
float4 threeDGlassesShader(
    coreimage::sampler src
) {
    float2 coord = src.coord();
    float alpha = sample(src, coord).a;

    float2 redCoord = coord + float2(-4.0, -3.0);
    float2 greenCoord = coord + float2(0.0, 3.0);
    float2 blueCoord = coord + float2(4.0, -3.0);

    float red = sample(src, redCoord).r;
    float green = sample(src, greenCoord).g;
    float blue = sample(src, blueCoord).b;

    return float4(red, green, blue, alpha);
}

[[ stitchable ]]
float4 glitchShader(
    coreimage::sampler src,
    float width,
    float height,
    float time
) {
    float2 coord = src.coord();
    float normalizedY = coord.y / height;
    float bandOne = fract(time * 0.27);
    float bandTwo = fract(time * 0.53 + 0.17);

    float glitchStrength = 0.0;
    if (fabs(normalizedY - bandOne) < 0.05) {
        glitchStrength += 0.7;
    }
    if (fabs(normalizedY - bandTwo) < 0.03) {
        glitchStrength += 1.1;
    }

    float sinSeed = sin((coord.y * 0.35) + (time * 25.0));
    float randomSeed = fract(sin(dot(coord + float2(time, time), float2(12.9898, 78.233))) * 43758.5453);
    float horizontalJitter = glitchStrength * ((randomSeed - 0.5) * 40.0 + sinSeed * 12.0);
    float verticalJitter = glitchStrength * sin((coord.x * 0.18) + (time * 30.0)) * 10.0;

    float2 shiftedCoord = coord + float2(horizontalJitter, verticalJitter);
    shiftedCoord.x = clamp(shiftedCoord.x, 0.0f, width - 1.0f);
    shiftedCoord.y = clamp(shiftedCoord.y, 0.0f, height - 1.0f);

    float channelSplit = glitchStrength * 3.5;

    float2 redCoord = shiftedCoord + float2(-channelSplit, channelSplit * 0.6);
    float2 blueCoord = shiftedCoord + float2(channelSplit, -channelSplit * 0.6);
    redCoord.x = clamp(redCoord.x, 0.0f, width - 1.0f);
    redCoord.y = clamp(redCoord.y, 0.0f, height - 1.0f);
    blueCoord.x = clamp(blueCoord.x, 0.0f, width - 1.0f);
    blueCoord.y = clamp(blueCoord.y, 0.0f, height - 1.0f);

    float4 base = sample(src, shiftedCoord);
    float red = sample(src, redCoord).r;
    float blue = sample(src, blueCoord).b;

    return float4(red, base.g, blue, base.a);
}
