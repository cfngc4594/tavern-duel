// Independent built-in-pipeline compatibility implementation, NOT Blizzard's shader.
// Native UVs, alpha and source color are used; source vertex RGB is retained but
// disabled by default because its semantics are shader-dependent. No baked shadow.
Shader "HearthstoneDesktop/OriginalCardCompatibility"
{
    Properties
    {
        _MainTex ("Original main texture", 2D) = "white" {}
        _Color ("Original material color", Color) = (1,1,1,1)
        _Cutoff ("Alpha cutoff", Range(0,1)) = 0.01
        _UseVertexColor ("Verified vertex color semantics", Float) = 0
    }
    SubShader
    {
        Tags { "Queue"="AlphaTest" "RenderType"="TransparentCutout" }
        Pass
        {
            Cull Back ZWrite On ZTest LEqual
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            float _Cutoff, _UseVertexColor;
            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; fixed4 color : COLOR; };
            struct v2f { float4 position : SV_POSITION; float2 uv : TEXCOORD0; fixed4 color : COLOR; };
            v2f vert(appdata input)
            {
                v2f output;
                output.position = UnityObjectToClipPos(input.vertex);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.color = lerp(fixed4(1,1,1,1), input.color, saturate(_UseVertexColor));
                return output;
            }
            fixed4 frag(v2f input) : SV_Target
            {
                fixed4 color = tex2D(_MainTex, input.uv) * _Color * input.color;
                clip(color.a - _Cutoff);
                return color;
            }
            ENDCG
        }
    }
    Fallback Off
}
