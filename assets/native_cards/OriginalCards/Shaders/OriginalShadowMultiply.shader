// Source: Hero/Multiply/Multiply, path ID -870869104636564592.
// Verified original bundled Metal and render state in shadow_shader_evidence.json.
// Selected HeroPowerShadow has _LightingBlend=0 and black _Color, so its output
// reduces exactly to original texture RGB under Blend DstColor Zero.
Shader "HearthstoneDesktop/OriginalShadowMultiply"
{
    Properties
    {
        _MainTex ("Original shadow texture", 2D) = "white" {}
        _Color ("Original color", Color) = (0,0,0,1)
        _LightingBlend ("Source lighting blend", Float) = 0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Pass
        {
            Cull Back ZWrite Off ZTest LEqual
            Blend DstColor Zero
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            sampler2D _MainTex; float4 _MainTex_ST, _Color;
            struct a { float4 position:POSITION; float2 uv:TEXCOORD0; float4 color:COLOR; };
            struct v { float4 position:SV_POSITION; float2 uv:TEXCOORD0; float4 color:COLOR; };
            v vert(a i) { v o; o.position=UnityObjectToClipPos(i.position); o.uv=TRANSFORM_TEX(i.uv,_MainTex); o.color=i.color*_Color; return o; }
            float4 frag(v i):SV_Target { return float4(tex2D(_MainTex,i.uv).rgb+i.color.rgb,0); }
            ENDCG
        }
    }
    Fallback Off
}
