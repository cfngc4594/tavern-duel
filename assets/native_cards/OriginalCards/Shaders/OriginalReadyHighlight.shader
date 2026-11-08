// Selected same-build Custom/Selection/Highlight Metal translation.
// See ready_highlight_bindings.json and highlight_shader_evidence.json.
Shader "HearthstoneDesktop/OriginalReadyHighlight"
{
    Properties
    {
        _MainTex ("Original silhouette", 2D) = "black" {}
        _FlareTex ("Original flare", 2D) = "black" {}
        _Color ("Color", Color) = (1,1,1,1)
        _Colorize ("Colorize", Color) = (1,1,1,1)
        _HiColor ("High color", Color) = (1,1,1,1)
        _ColorIntensity ("Color intensity", Float) = 1
        _Intensity ("Intensity", Float) = 1
        _FlareIntensity ("Flare intensity", Float) = 1
        _VflareSpeed ("Flare speed", Float) = 0
        _UflareScale ("Flare U", Float) = 1
        _VflareScale ("Flare V", Float) = 1
        _Seed ("Seed", Float) = 0
        _ColorAlphaWeight ("Color alpha weight", Float) = 1
        _TexCoordTwoWeight ("UV1 weight", Float) = 1
        _ShaderTime ("Source shader clock", Float) = 0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" }
        Cull Off ZWrite Off ZTest LEqual Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            sampler2D _MainTex, _FlareTex;
            float4 _MainTex_ST, _Color, _Colorize, _HiColor;
            float _ColorIntensity, _Intensity, _FlareIntensity, _VflareSpeed;
            float _UflareScale, _VflareScale, _Seed, _ColorAlphaWeight, _TexCoordTwoWeight, _ShaderTime;
            struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; float2 uv1:TEXCOORD1; float4 color:COLOR; };
            struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; float4 flare:TEXCOORD1; };
            v2f vert(appdata v)
            {
                v2f o; o.pos=UnityObjectToClipPos(v.vertex);
                o.uv=TRANSFORM_TEX(v.uv,_MainTex);
                o.flare.xy=lerp(o.uv,TRANSFORM_TEX(v.uv1,_MainTex),_TexCoordTwoWeight);
                o.flare.z=v.color.r; o.flare.w=_Seed+_ShaderTime;
                return o;
            }
            float4 frag(v2f i):SV_Target
            {
                float mask=tex2D(_MainTex,i.uv).r*_Intensity*1.20000005;
                float2 uv=float2(i.flare.x*_UflareScale+i.flare.w*0.0500000007,
                                 mask*_VflareScale+i.flare.w*_VflareSpeed);
                float flare=(tex2D(_FlareTex,uv).r*i.flare.z+mask)*2*mask*_FlareIntensity;
                float3 color=lerp(_Color.rgb,_HiColor.rgb*flare,flare)*_ColorIntensity;
                float alpha=lerp(1,i.flare.z,_ColorAlphaWeight)*flare;
                return float4(color,alpha)*_Colorize;
            }
            ENDCG
        }
    }
}
