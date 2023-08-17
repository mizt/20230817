#include <metal_stdlib>
using namespace metal;

struct VertInOut {
    float4 pos[[position]];
    float2 texcoord[[user(texturecoord)]];
};

struct FragmentShaderArguments {
    texture2d<float> texture[[id(0)]];
};

vertex VertInOut vertexShader(constant float4 *pos[[buffer(0)]],constant packed_float2  *texcoord[[buffer(1)]],uint vid[[vertex_id]]) {
    VertInOut outVert;
    outVert.pos = pos[vid];
    outVert.texcoord = float2(texcoord[vid][0],1.0-texcoord[vid][1]);
    return outVert;
}

fragment float4 fragmentShader(VertInOut inFrag[[stage_in]],constant FragmentShaderArguments &args[[buffer(0)]]) {
    constexpr sampler sampler(address::clamp_to_edge,filter::linear);
    
    float2 rg = args.texture.sample(sampler,inFrag.texcoord).rg; 
    
    unsigned short x = int(rg.g*65535);
    unsigned short y = int(rg.r*65535);
    
    x+=1920*4;
    y+=1080*4;
    
    return float4((y&0xFF00|x&0xFF)/65535.0,(x&0xFF00|y&0xFF)/65535.0,0,0);
}
