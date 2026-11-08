// TextMesh compatibility text. Source UberText anchoring is retained; proprietary
// outline, font, curved-text and render-to-texture algorithms are not reproduced.
Shader "HearthstoneDesktop/OriginalCardText"
{
    Properties { _MainTex ("Font atlas", 2D) = "white" {} _Color ("Tint", Color) = (1,1,1,1) }
    SubShader
    {
        Tags { "Queue"="Transparent+50" "RenderType"="Transparent" }
        Pass
        {
            Lighting Off Cull Off ZWrite Off ZTest LEqual
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            sampler2D _MainTex; fixed4 _Color;
            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; fixed4 color : COLOR; };
            struct v2f { float4 position : SV_POSITION; float2 uv : TEXCOORD0; fixed4 color : COLOR; };
            v2f vert(appdata i) { v2f o; o.position=UnityObjectToClipPos(i.vertex); o.uv=i.uv; o.color=i.color*_Color; return o; }
            fixed4 frag(v2f i) : SV_Target { fixed4 c=i.color; c.a*=tex2D(_MainTex,i.uv).a; return c; }
            ENDCG
        }
    }
    Fallback Off
}
