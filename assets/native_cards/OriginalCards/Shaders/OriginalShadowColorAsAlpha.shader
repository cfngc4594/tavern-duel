// Source: Effects/FX_Transparent_ColorAsAlpha, path ID -2557555604182605517.
// Verified original bundled Metal fragment and render state in shadow_shader_evidence.json.
Shader "HearthstoneDesktop/OriginalShadowColorAsAlpha"
{
    Properties
    {
        _MainTex ("Original shadow texture", 2D) = "black" {}
        _Color ("Original color", Color) = (1,1,1,1)
        _Intensity ("Original intensity", Float) = 1
        _AlphaIntensity ("Original alpha intensity", Float) = 1
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Pass
        {
            Cull Off ZWrite Off ZTest LEqual
            Blend One OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            sampler2D _MainTex; float4 _MainTex_ST, _Color; float _Intensity, _AlphaIntensity;
            struct a { float4 position:POSITION; float2 uv:TEXCOORD0; };
            struct v { float4 position:SV_POSITION; float2 uv:TEXCOORD0; };
            v vert(a i) { v o; o.position=UnityObjectToClipPos(i.position); o.uv=TRANSFORM_TEX(i.uv,_MainTex); return o; }
            float4 frag(v i):SV_Target
            {
                float3 sample=tex2D(_MainTex,i.uv).rgb;
                return float4(sample*_Color.rgb,dot(float3(0.3,0.59,0.11),sample)*_AlphaIntensity)*_Intensity;
            }
            ENDCG
        }
    }
    Fallback Off
}
