Shader "Unlit/Scene_Mirrior_Code"
{
    Properties
    {
        _Diffuse ("Diffuse", 2D) = "white" {}
        [IntRange]_Index ("物体模板编号", Range(0,255)) = 1
    }
    SubShader
    {
        Tags { "Queue"="AlphaTest+20" }
        LOD 100

        Pass
        {
            Stencil
            {
                Ref [_Index]
                Comp Equal
            }
            CGPROGRAM
            #pragma multi_compile_instancing
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _Diffuse;
            float4 _Diffuse_ST;

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _Diffuse);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                
                UNITY_SETUP_INSTANCE_ID(i);
                // sample the texture
                fixed4 col = tex2D(_Diffuse, i.uv);
                return col;
            }
            ENDCG
        }
    }
}
