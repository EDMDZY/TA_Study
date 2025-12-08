Shader "Unlit/01_MiniShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv0 :TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;


            v2f vert (appdata v)
            {
                v2f o;
                float4 worldPos = mul(UNITY_MATRIX_M, v.vertex);
                float4 viewPos = mul(UNITY_MATRIX_V, worldPos);
                float4 clipPos = mul(UNITY_MATRIX_P, viewPos);
                o.pos = clipPos;

                o.uv0 = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float4 final = tex2D(_MainTex, i.uv0);
                return  final;
            }
            ENDCG
        }
    }
}
