#include <metal_stdlib>
using namespace metal;

kernel void pixellate(
    texture2d<half, access::read> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    constant float &pixelSize [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    uint2 samplePos = uint2(
        pixelSize * round(float(gid.x) / pixelSize),
        pixelSize * round(float(gid.y) / pixelSize)
    );
    
    samplePos.x = min(samplePos.x, inTexture.get_width() - 1);
    samplePos.y = min(samplePos.y, inTexture.get_height() - 1);
    
    half4 color = inTexture.read(samplePos);
    outTexture.write(color, gid);
}

kernel void crtScreen(
    texture2d<half, access::read> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    constant float &time [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    half4 color = inTexture.read(gid);
    
    const half minIntensity = 0.005;
    
    if (all(abs(color.rgb - half3(0.0, 0.0, 0.0)) < half3(0.01, 0.01, 0.01))) {
        color.rgb += half3(minIntensity, minIntensity, minIntensity);
    }
    
    if (all(abs(color.rgb - half3(1.0, 1.0, 1.0)) < half3(0.01, 0.01, 0.01))) {
        color.rgb -= half3(minIntensity, minIntensity, minIntensity);
    }
    
    const half scanlineIntensity = 0.3;
    const half scanlineFrequency = 0.8;
    half scanlineValue = sin((M_PI_H * float(gid.y) + time * 50.0) * scanlineFrequency) * scanlineIntensity;
    
    outTexture.write(half4(color.rgb - scanlineValue, color.a), gid);
}

kernel void glitch(
    texture2d<half, access::read> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    constant float &time [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float width = float(inTexture.get_width());
    float bandMin = tan(time * 4.0);
    float bandMax = tan(time * 4.0) + 0.015;
    
    float normalizedX = float(gid.x) / width;
    uint2 samplePos = gid;
    
    if (normalizedX > bandMin && normalizedX < bandMax) {
        int yOffset = int(6.0 * sin(10.0 * time + (float(gid.x) / 5.0)));
        int newY = int(gid.y) + yOffset;
        newY = clamp(newY, 0, int(inTexture.get_height()) - 1);
        samplePos.y = uint(newY);
    }
    
    half4 color = inTexture.read(samplePos);
    outTexture.write(color, gid);
}

kernel void threeDGlasses(
    texture2d<half, access::read> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    half4 color = inTexture.read(gid);
    
    int2 redOffset = int2(-22, -22);
    int2 redCoord = int2(gid) + redOffset;
    redCoord.x = clamp(redCoord.x, 0, int(inTexture.get_width()) - 1);
    redCoord.y = clamp(redCoord.y, 0, int(inTexture.get_height()) - 1);
    color.r = inTexture.read(uint2(redCoord)).r;
    
    int2 blueOffset = int2(11, 11);
    int2 blueCoord = int2(gid) + blueOffset;
    blueCoord.x = clamp(blueCoord.x, 0, int(inTexture.get_width()) - 1);
    blueCoord.y = clamp(blueCoord.y, 0, int(inTexture.get_height()) - 1);
    color.b = inTexture.read(uint2(blueCoord)).b;
    
    outTexture.write(color, gid);
}

kernel void spectral(
    texture2d<half, access::read> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    half4 color = inTexture.read(gid);
    half3 grayscaleWeights = half3(0.2125, 0.7154, 0.0721);
    half avgLuminescence = dot(color.rgb, grayscaleWeights);
    half invertedLuminescence = 1.0 - avgLuminescence;
    half scaledLumin = pow(invertedLuminescence, half(3.0));
    
    outTexture.write(half4(scaledLumin, scaledLumin, scaledLumin, color.a), gid);
}

kernel void alien(
    texture2d<half, access::read> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    half4 color = inTexture.read(gid);
    outTexture.write(half4(color.b, color.r, color.g, color.a), gid);
}

kernel void alien2(
    texture2d<half, access::read> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    half4 color = inTexture.read(gid);
    outTexture.write(half4(color.g, color.b, color.r, color.a), gid);
}

kernel void inversion(
    texture2d<half, access::read> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    half4 color = inTexture.read(gid);
    outTexture.write(half4(1.0 - color.r, 1.0 - color.g, 1.0 - color.b, color.a), gid);
}

kernel void passthrough(
    texture2d<half, access::read> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    half4 color = inTexture.read(gid);
    outTexture.write(color, gid);
}