#include <metal_stdlib>
#include <metal_texture>
using namespace metal;
constant uint32_t rp_output_remap_mask [[ function_constant(1) ]];
constant const uint rp_output_remap_0 = (rp_output_remap_mask >> 0) & 0xF;
struct FGlobals_Type
{
    float2 _GlobalMipBias;
    float4 _MainLightPosition;
    float4 _MainLightColor;
};

struct UnityPerDraw_Type
{
    float4 hlslcc_mtx4x4unity_ObjectToWorld[4];
    float4 hlslcc_mtx4x4unity_WorldToObject[4];
    float4 unity_LODFade;
    float4 unity_WorldTransformParams;
    float4 unity_RenderingLayer;
    float4 unity_LightData;
    float4 unity_LightIndices[2];
    float4 unity_ProbesOcclusion;
    float4 unity_SpecCube0_HDR;
    float4 unity_SpecCube1_HDR;
    float4 unity_SpecCube0_BoxMax;
    float4 unity_SpecCube0_BoxMin;
    float4 unity_SpecCube0_ProbePosition;
    float4 unity_SpecCube0_Rotation;
    float4 unity_SpecCube1_BoxMax;
    float4 unity_SpecCube1_BoxMin;
    float4 unity_SpecCube1_ProbePosition;
    float4 unity_SpecCube1_Rotation;
    float4 unity_LightmapST;
    float4 unity_DynamicLightmapST;
    float4 unity_SHAr;
    float4 unity_SHAg;
    float4 unity_SHAb;
    float4 unity_SHBr;
    float4 unity_SHBg;
    float4 unity_SHBb;
    float4 unity_SHC;
    float4 unity_RendererBounds_Min;
    float4 unity_RendererBounds_Max;
    float4 hlslcc_mtx4x4unity_MatrixPreviousM[4];
    float4 hlslcc_mtx4x4unity_MatrixPreviousMI[4];
    float4 unity_MotionVectorsParams;
    float4 unity_SpriteColor;
    float4 unity_SpriteProps;
};

struct UnityPerMaterial_Type
{
    float4 _MainTex_ST;
    float4 _Color;
};

struct Mtl_FragmentIn
{
    float2 TEXCOORD0 [[ user(TEXCOORD0) ]] ;
    float3 TEXCOORD2 [[ user(TEXCOORD2) ]] ;
    float3 NORMAL0 [[ user(NORMAL0) ]] ;
};

struct Mtl_FragmentOut
{
    float4 SV_Target0 [[ color(rp_output_remap_0) ]];
};

fragment Mtl_FragmentOut xlatMtlMain(
    constant FGlobals_Type& FGlobals [[ buffer(0) ]],
    constant UnityPerDraw_Type& UnityPerDraw [[ buffer(1) ]],
    constant UnityPerMaterial_Type& UnityPerMaterial [[ buffer(2) ]],
    sampler sampler_MainTex [[ sampler (0) ]],
    texture2d<float, access::sample > _MainTex [[ texture(0) ]] ,
    Mtl_FragmentIn input [[ stage_in ]])
{
    Mtl_FragmentOut output;
    float3 u_xlat0;
    float4 u_xlat1;
    float3 u_xlat2;
    u_xlat0.x = dot(input.NORMAL0.xyz, input.NORMAL0.xyz);
    u_xlat0.x = rsqrt(u_xlat0.x);
    u_xlat0.xyz = u_xlat0.xxx * input.NORMAL0.xyz;
    u_xlat0.x = dot(u_xlat0.xyz, FGlobals._MainLightPosition.xyz);
    u_xlat0.x = clamp(u_xlat0.x, 0.0f, 1.0f);
    u_xlat2.xyz = FGlobals._MainLightColor.xyz * UnityPerDraw.unity_LightData.zzz;
    u_xlat0.xyz = fma(u_xlat2.xyz, u_xlat0.xxx, input.TEXCOORD2.xyz);
    u_xlat1 = _MainTex.sample(sampler_MainTex, input.TEXCOORD0.xy, bias(FGlobals._GlobalMipBias.xyxx.x));
    u_xlat1 = u_xlat1 * UnityPerMaterial._Color;
    output.SV_Target0.xyz = u_xlat0.xyz * u_xlat1.xyz;
    output.SV_Target0.w = u_xlat1.w;
    return output;
}
