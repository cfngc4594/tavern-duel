// Selected-material translation of verified same-build Metal shader
// Hero/Diffuse/DiffuseAlphaMaskScroller, path ID 9099378368919310605.
// MainTex alpha masks scrolling color, never transparency. Built-in lighting
// globals replace URP globals; exact cross-pipeline lighting parity is not claimed.
Shader "HearthstoneDesktop/OriginalGemAlphaMask"
{
    Properties
    {
        _MainTex ("Original gem RGB / scroll mask A", 2D) = "white" {}
        _ScrollingTex ("Original scrolling texture", 2D) = "black" {}
        _Intensity ("Scroll intensity", Float) = 1
        _TintColor ("Source tint", Color) = (1,1,1,1)
        _tint ("Source scroll tint", Color) = (1,1,1,1)
        _Fade ("Source fade", Color) = (1,1,1,1)
        _XSpeed ("Source X speed", Float) = 5
        _YSpeed ("Source Y speed", Float) = .2
        _ScaleX ("Source X scale", Float) = 1
        _ScaleY ("Source Y scale", Float) = 1
        _LightingBlend ("Source lighting blend", Float) = 0
    }
    SubShader
    {
        Tags { "Queue"="Geometry" "RenderType"="Opaque" }
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            Cull Back ZWrite On ZTest LEqual Blend One Zero
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            sampler2D _MainTex, _ScrollingTex;
            float4 _MainTex_ST, _TintColor, _tint, _Fade;
            float _Intensity, _XSpeed, _YSpeed, _ScaleX, _ScaleY, _LightingBlend;
            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f { float4 position : SV_POSITION; float4 uv : TEXCOORD0; float4 tint : COLOR0; };
            v2f vert(appdata i)
            {
                v2f o;
                o.position = UnityObjectToClipPos(i.vertex);
                o.uv.xy = TRANSFORM_TEX(i.uv, _MainTex);
                o.uv.zw = i.uv * float2(_ScaleX, _ScaleY) + _Time.xx * float2(_XSpeed, _YSpeed);
                float3 ambient = saturate(1.055 * pow(abs(float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w)), 1.0 / 2.4) - .055);
                o.tint = float4(lerp(float3(1,1,1), ambient + _LightColor0.rgb, _LightingBlend), 1) * _TintColor;
                return o;
            }
            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 gem = tex2D(_MainTex, i.uv.xy);
                // Source gem and scroller samplers are Repeat; preserve those
                // importer settings so UV derivatives remain continuous.
                fixed scroll = tex2D(_ScrollingTex, i.uv.zw).r;
                return fixed4((gem.rgb + scroll * _tint.rgb * gem.a * 1.5 * _Intensity) * _Fade.rgb, 1) * i.tint;
            }
            ENDCG
        }
    }
    Fallback Off
}
