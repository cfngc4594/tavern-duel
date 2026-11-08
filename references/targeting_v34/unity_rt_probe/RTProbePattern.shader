Shader "Hidden/RTProbePattern" {SubShader {Pass {ZTest Always Cull Off ZWrite Off
CGPROGRAM
#pragma vertex vert_img
#pragma fragment frag
#include "UnityCG.cginc"
float4 frag(v2f_img i):SV_Target {float r=i.uv.x<0.5?0.2:0.8;return float4(r,0,0,1);}
ENDCG
}}}
