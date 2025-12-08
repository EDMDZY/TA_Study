Shader "Unlit/Vice_Code"
{
    Properties
    {
        _MainTex ("主帖图", 2D) = "white" {}
        _Grow ("生长进度", Range(-1,1.5)) = 1
        _Expand ("生长末尾开口大小", Float) = 1
        _Scale ("整体缩放", Float) = 0
        _GrowMin ("生长时最小阈值", Range(0, 1)) = 0.6
        _GrowMax ("生长时最大阈值", Range(0, 1.5)) = 1.35
        _EndMin ("完成生长最小阈值", Range(0, 1)) = 0.6
        _EndMax ("完成生长最大阈值", Range(0, 1.5)) = 1
        
        
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Grow;
            float _Expand;
            float _Scale;
            float _GrowMin;
            float _GrowMax;
            float _EndMin;
            float _EndMax;

            v2f vert (appdata v)
            {
                v2f o;
                
                float weight_Expand = smoothstep(_GrowMin, _GrowMax, v.uv.y - _Grow);
                float weight_End = smoothstep(_EndMin, _EndMax, v.uv.y);
                float finalWeight = max(weight_Expand, weight_End);

                float3 vertex_offset = v.normal * finalWeight * 0.01f * _Expand;
                float3 vertex_scale = v.normal * _Scale * 0.01f;
                float3 finalVertex = vertex_offset + vertex_scale;

                v.vertex.xyz = v.vertex.xyz + finalVertex;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                clip(1 - (i.uv.y - _Grow));
                fixed4 col = tex2D(_MainTex, i.uv);

                return col;
            }
            ENDCG
        }
    }
}
