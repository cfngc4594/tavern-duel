#include <metal_stdlib>
#include <metal_texture>
using namespace metal;
struct VGlobals_Type
{
    float4 _MainLightColor;
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
    float4 _SecondTex_ST;
    float4 _SecondTint;
    float4 _Color;
    float _BlendIntensity;
    float _LightingBlend;
};

struct Mtl_VertexIn
{
    float4 POSITION0 [[ attribute(0) ]] ;
    float2 TEXCOORD0 [[ attribute(1) ]] ;
    float2 TEXCOORD1 [[ attribute(2) ]] ;
    float4 COLOR0 [[ attribute(3) ]] ;
};

struct Mtl_VertexOut
{
    float4 mtl_Position [[ position, invariant ]];
    float2 TEXCOORD0 [[ user(TEXCOORD0) ]];
    float2 TEXCOORD1 [[ user(TEXCOORD1) ]];
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
    output.TEXCOORD1.xy = fma(input.TEXCOORD1.xy, UnityPerMaterial._SecondTex_ST.xy, UnityPerMaterial._SecondTex_ST.zw);
    u_xlat0.x = abs(UnityPerDraw.unity_SHAr.w);
    u_xlat0.y = abs(UnityPerDraw.unity_SHAg.w);
    u_xlat0.z = abs(UnityPerDraw.unity_SHAb.w);
    u_xlat0.xyz = log2(u_xlat0.xyz);
    u_xlat0.xyz = u_xlat0.xyz * float3(0.416666657, 0.416666657, 0.416666657);
    u_xlat0.xyz = exp2(u_xlat0.xyz);
    u_xlat0.xyz = fma(u_xlat0.xyz, float3(1.05499995, 1.05499995, 1.05499995), float3(-0.0549999997, -0.0549999997, -0.0549999997));
    u_xlat0.xyz = clamp(u_xlat0.xyz, 0.0f, 1.0f);
    u_xlat0.xyz = u_xlat0.xyz + VGlobals._MainLightColor.xyz;
    u_xlat0.w = 1.0;
    u_xlat0 = u_xlat0 + (-input.COLOR0);
    u_xlat0 = fma(float4(UnityPerMaterial._LightingBlend), u_xlat0, input.COLOR0);
    output.COLOR0 = u_xlat0 * UnityPerMaterial._Color;
    return output;
}
