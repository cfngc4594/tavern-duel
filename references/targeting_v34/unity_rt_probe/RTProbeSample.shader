Shader "Hidden/RTProbeSample" {SubShader {Pass {ZTest Always Cull Off ZWrite Off
CGPROGRAM
#pragma vertex vert_img
#pragma fragment frag
#include "UnityCG.cginc"
sampler2D _ProbeSource;
float4 frag(v2f_img i):SV_Target {float u=i.uv.x<0.25?-0.25:(i.uv.x<0.5?0.25:(i.uv.x<0.75?0.75:1.25));return tex2D(_ProbeSource,float2(u,0.5));}
ENDCG
}}}
