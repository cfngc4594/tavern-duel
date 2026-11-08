#include <metal_stdlib>
#include <metal_texture>
using namespace metal;
struct VGlobals_Type
{
    float4 hlslcc_mtx4x4unity_MatrixVP[4];
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
    float _OffsetX;
    float _OffsetY;
    float _Edge;
};

struct Mtl_VertexIn
{
    float4 POSITION0 [[ attribute(0) ]] ;
    float2 TEXCOORD0 [[ attribute(1) ]] ;
    float4 COLOR0 [[ attribute(2) ]] ;
};

struct Mtl_VertexOut
{
    float4 mtl_Position [[ position, invariant ]];
    float2 TEXCOORD0 [[ user(TEXCOORD0) ]];
    float2 TEXCOORD1 [[ user(TEXCOORD1) ]];
    float2 TEXCOORD2 [[ user(TEXCOORD2) ]];
    float2 TEXCOORD3 [[ user(TEXCOORD3) ]];
    float2 TEXCOORD4 [[ user(TEXCOORD4) ]];
    float4 COLOR0 [[ user(COLOR0) ]];
};

vertex Mtl_VertexOut xlatMtlMain(
    constant VGlobals_Type& VGlobals [[ buffer(0) ]],
    constant UnityPerDraw_Type& UnityPerDraw [[ buffer(1) ]],
    constant UnityPerMaterial_Type& UnityPerMaterial [[ buffer(2) ]],
    Mtl_VertexIn input [[ stage_in ]])
{
    Mtl_VertexOut output;
    float4 u_xlat0;
    float4 u_xlat1;
    u_xlat0 = input.POSITION0.yyyy * UnityPerDraw.hlslcc_mtx4x4unity_ObjectToWorld[1];
    u_xlat0 = fma(UnityPerDraw.hlslcc_mtx4x4unity_ObjectToWorld[0], input.POSITION0.xxxx, u_xlat0);
    u_xlat0 = fma(UnityPerDraw.hlslcc_mtx4x4unity_ObjectToWorld[2], input.POSITION0.zzzz, u_xlat0);
    u_xlat0 = u_xlat0 + UnityPerDraw.hlslcc_mtx4x4unity_ObjectToWorld[3];
    u_xlat1 = u_xlat0.yyyy * VGlobals.hlslcc_mtx4x4unity_MatrixVP[1];
    u_xlat1 = fma(VGlobals.hlslcc_mtx4x4unity_MatrixVP[0], u_xlat0.xxxx, u_xlat1);
    u_xlat1 = fma(VGlobals.hlslcc_mtx4x4unity_MatrixVP[2], u_xlat0.zzzz, u_xlat1);
    output.mtl_Position = fma(VGlobals.hlslcc_mtx4x4unity_MatrixVP[3], u_xlat0.wwww, u_xlat1);
    output.TEXCOORD0.xy = fma(input.TEXCOORD0.xy, UnityPerMaterial._MainTex_ST.xy, UnityPerMaterial._MainTex_ST.zw);
    u_xlat0.xy = input.TEXCOORD0.xy + float2(UnityPerMaterial._OffsetX, UnityPerMaterial._OffsetY);
    output.TEXCOORD1.xy = fma(u_xlat0.xy, UnityPerMaterial._MainTex_ST.xy, UnityPerMaterial._MainTex_ST.zw);
    u_xlat0.zw = input.TEXCOORD0.xy + (-float2(UnityPerMaterial._OffsetX, UnityPerMaterial._OffsetY));
    output.TEXCOORD2.xy = fma(u_xlat0.zw, UnityPerMaterial._MainTex_ST.xy, UnityPerMaterial._MainTex_ST.zw);
    output.TEXCOORD3.xy = fma(u_xlat0.xw, UnityPerMaterial._MainTex_ST.xy, UnityPerMaterial._MainTex_ST.zw);
    output.TEXCOORD4.xy = fma(u_xlat0.zy, UnityPerMaterial._MainTex_ST.xy, UnityPerMaterial._MainTex_ST.zw);
    output.COLOR0 = input.COLOR0 * UnityPerMaterial._Color;
    return output;
}

// ---- NEXT COMPILED VARIANT ----
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
    float4 _MainTex_ST;
    float4 _Color;
    float _OffsetX;
    float _OffsetY;
    float _Edge;
};

struct Mtl_FragmentIn
{
    float2 TEXCOORD0 [[ user(TEXCOORD0) ]] ;
    float2 TEXCOORD1 [[ user(TEXCOORD1) ]] ;
    float2 TEXCOORD2 [[ user(TEXCOORD2) ]] ;
    float2 TEXCOORD3 [[ user(TEXCOORD3) ]] ;
    float2 TEXCOORD4 [[ user(TEXCOORD4) ]] ;
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
    Mtl_FragmentIn input [[ stage_in ]])
{
    Mtl_FragmentOut output;
    float4 u_xlat0;
    float u_xlat1;
    u_xlat0.x = _MainTex.sample(sampler_MainTex, input.TEXCOORD1.xy, bias(FGlobals._GlobalMipBias.xyxx.x)).w;
    u_xlat1 = _MainTex.sample(sampler_MainTex, input.TEXCOORD2.xy, bias(FGlobals._GlobalMipBias.xyxx.x)).w;
    u_xlat0.x = u_xlat1 + u_xlat0.x;
    u_xlat1 = _MainTex.sample(sampler_MainTex, input.TEXCOORD3.xy, bias(FGlobals._GlobalMipBias.xyxx.x)).w;
    u_xlat0.x = u_xlat1 + u_xlat0.x;
    u_xlat1 = _MainTex.sample(sampler_MainTex, input.TEXCOORD4.xy, bias(FGlobals._GlobalMipBias.xyxx.x)).w;
    u_xlat0.x = u_xlat1 + u_xlat0.x;
    u_xlat0.w = u_xlat0.x * UnityPerMaterial._Edge;
    u_xlat0.xyz = _MainTex.sample(sampler_MainTex, input.TEXCOORD0.xy, bias(FGlobals._GlobalMipBias.xyxx.x)).xyz;
    output.SV_Target0 = u_xlat0 * input.COLOR0;
    return output;
}
