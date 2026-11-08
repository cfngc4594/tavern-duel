#include <metal_stdlib>
#include <metal_texture>
using namespace metal;
constant uint32_t rp_output_remap_mask [[ function_constant(1) ]];
constant const uint rp_output_remap_0 = (rp_output_remap_mask >> 0) & 0xF;
struct FGlobals_Type
{
    float2 _GlobalMipBias;
};

struct UnityPerMaterial_Type
{
    float4 _Color;
    float4 _SecondTint;
    float _BlendIntensity;
    float _LightingBlend;
    float4 _MainTex_ST;
    float4 _SecondTex_ST;
};

struct Mtl_FragmentIn
{
    float2 TEXCOORD0 [[ user(TEXCOORD0) ]] ;
    float2 TEXCOORD1 [[ user(TEXCOORD1) ]] ;
    float4 COLOR0 [[ user(COLOR0) ]] ;
};

struct Mtl_FragmentOut
{
    float4 SV_TARGET0 [[ color(rp_output_remap_0) ]];
};

fragment Mtl_FragmentOut xlatMtlMain(
    constant FGlobals_Type& FGlobals [[ buffer(0) ]],
    constant UnityPerMaterial_Type& UnityPerMaterial [[ buffer(1) ]],
    sampler sampler_MainTex [[ sampler (0) ]],
    sampler sampler_SecondTex [[ sampler (1) ]],
    texture2d<float, access::sample > _MainTex [[ texture(0) ]] ,
    texture2d<float, access::sample > _SecondTex [[ texture(1) ]] ,
    Mtl_FragmentIn input [[ stage_in ]])
{
    Mtl_FragmentOut output;
    float4 u_xlat0;
    float4 u_xlat1;
    float4 u_xlat2;
    u_xlat0 = _SecondTex.sample(sampler_SecondTex, input.TEXCOORD1.xy, bias(FGlobals._GlobalMipBias.xyxx.x));
    u_xlat0 = u_xlat0 * UnityPerMaterial._SecondTint;
    u_xlat0 = u_xlat0 * float4(UnityPerMaterial._BlendIntensity);
    u_xlat1 = _MainTex.sample(sampler_MainTex, input.TEXCOORD0.xy, bias(FGlobals._GlobalMipBias.xyxx.x));
    u_xlat2 = fma(u_xlat1, u_xlat0, (-u_xlat1));
    u_xlat0 = fma(u_xlat0.wwww, u_xlat2, u_xlat1);
    u_xlat1 = u_xlat0 + float4(0.150000006, 0.150000006, 0.150000006, 0.150000006);
    u_xlat1 = u_xlat1 * input.COLOR0;
    output.SV_TARGET0 = min(u_xlat0, u_xlat1);
    return output;
}
