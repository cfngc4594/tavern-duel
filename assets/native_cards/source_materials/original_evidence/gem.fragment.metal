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
    float _Intensity;
    float4 _TintColor;
    float4 _tint;
    float4 _Fade;
    float4 _MainTex_ST;
    float _YSpeed;
    float _XSpeed;
    float _ScaleX;
    float _ScaleY;
    float _LightingBlend;
};

struct Mtl_FragmentIn
{
    float4 TEXCOORD0 [[ user(TEXCOORD0) ]] ;
    float4 COLOR0 [[ user(COLOR0) ]] ;
};

struct Mtl_FragmentOut
{
    float4 SV_Target0 [[ color(rp_output_remap_0) ]];
};

fragment Mtl_FragmentOut xlatMtlMain(
    constant FGlobals_Type& FGlobals [[ buffer(0) ]],
    constant UnityPerMaterial_Type& UnityPerMaterial [[ buffer(1) ]],
    sampler sampler_MainTex [[ sampler (0) ]],
    texture2d<float, access::sample > _MainTex [[ texture(0) ]] ,
    texture2d<float, access::sample > _ScrollingTex [[ texture(1) ]] ,
    Mtl_FragmentIn input [[ stage_in ]])
{
    Mtl_FragmentOut output;
    float4 u_xlat0;
    float4 u_xlat1;
    u_xlat0.x = _ScrollingTex.sample(sampler_MainTex, input.TEXCOORD0.zw, bias(FGlobals._GlobalMipBias.xyxx.x)).x;
    u_xlat0.xyz = u_xlat0.xxx * UnityPerMaterial._tint.xyz;
    u_xlat1 = _MainTex.sample(sampler_MainTex, input.TEXCOORD0.xy, bias(FGlobals._GlobalMipBias.xyxx.x));
    u_xlat0.xyz = u_xlat0.xyz * u_xlat1.www;
    u_xlat0.xyz = u_xlat0.xyz * float3(1.5, 1.5, 1.5);
    u_xlat0.xyz = fma(u_xlat0.xyz, float3(UnityPerMaterial._Intensity), u_xlat1.xyz);
    u_xlat0.xyz = u_xlat0.xyz * UnityPerMaterial._Fade.xyz;
    u_xlat0.w = 1.0;
    output.SV_Target0 = u_xlat0 * input.COLOR0;
    return output;
}
