Shader "Hidden/RTProbeSampleV" {SubShader {Pass {ZTest Always Cull Off ZWrite Off
CGPROGRAM
#pragma vertex vert_img
#pragma fragment frag
#include "UnityCG.cginc"
sampler2D _ProbeSourceV;
float4 frag(v2f_img i):SV_Target {float v=i.uv.x<0.25?-0.25:(i.uv.x<0.5?0.25:(i.uv.x<0.75?0.75:1.25));return tex2D(_ProbeSourceV,float2(0.5,v));}
ENDCG
}}}
