Shader "Unlit/MatCap_Code"
{
    Properties
    {
        _MainTex ("主贴图", 2D) = "white" {}
        _NormalTex ("法线贴图", 2D) = "white" {}
        _MatCap ("MatCap", 2D) = "white" {}
        _MatCapAdd ("MatCapAdd", 2D) = "white" {}
        _RampTex ("_RampTex", 2D) = "white" {}
        _MatCapStr ("MatCap强度", Float) = 1
        _MatCapAddStr ("MatCapAdd强度", Range(0,1)) = 0.2
        _PowStr ("Pow强度", Float) = 1
        
        [Toggle(_Rampcheck_ON)] _Rampcheck("Ramp Check", Float) = 1
        [Toggle(_MatCapcheck_ON)] _MatCapcheck("MatCap Check", Float) = 1
        [Toggle(_MatCapAddcheck_ON)] _MatCapAddcheck("MatCapAdd Check", Float) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _Rampcheck_ON
            #pragma shader_feature _MatCapcheck_ON
            #pragma shader_feature _MatCapAddcheck_ON
            
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal_WS : TEXCOORD1;
                float3 pos_WS : TEXCOORD2;
                float3 tangent_world : TEXCOORD3;
                float3 binormal_world : TEXCOORD4;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _NormalTex;
            float4 _NormalTex_ST;
            sampler2D _MatCap;
            float4 _MatCap_ST;
            sampler2D _MatCapAdd;
            float4 _MatCapAdd_ST;
            sampler2D _RampTex;
            float4 _RampTex_ST;

            float _MatCapStr;
            float _MatCapAddStr;
            float _PowStr;


            v2f vert(appdata v)
            {
                v2f o;
                o.pos_WS = mul(unity_ObjectToWorld, v.vertex);
                o.normal_WS = UnityObjectToWorldNormal(v.normal);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.tangent_world = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.binormal_world = normalize(cross(o.normal_WS, o.tangent_world)) * v.tangent.w;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                half3 normaldata = UnpackNormal(tex2D(_NormalTex, i.uv)); // 解码得到法线贴图数据信息
                // 构建TBN矩阵
                half3 tangent_dir = normalize(i.tangent_world);
                half3 binormal_dir = normalize(i.binormal_world);
                half3 normal_dir = normalize(i.normal_WS);
                float3x3 TBN = float3x3(tangent_dir, binormal_dir, normal_dir);
                // 通过TBN矩阵转换法线数据得到新的法线方向
                normal_dir = mul(normaldata, TBN);

                //matCap & matCapAdd
                float3 normal_VS = mul(UNITY_MATRIX_V, normal_dir).xyz;   // 因为CatMap贴图是基于观察空间的法线方向来采样的
                half2 matcapUV = normal_VS.xy * 0.5 + 0.5;                // 法线分量在视图空间中的范围是-1到1，纹理坐标需要0到1的范围

            #ifdef _MatCapcheck_ON
                half4 Matcap = tex2D(_MatCap, matcapUV) * _MatCapStr;
            #else
                half4 Matcap = 1;
            #endif

            #ifdef _MatCapAddcheck_ON 
                half4 MatcapAdd = tex2D(_MatCapAdd, matcapUV) * _MatCapAddStr;
            #else
                half4 MatcapAdd = half4(0,0,0,0);
            #endif
                
                // Ramp
                half3 viewDir = normalize(_WorldSpaceCameraPos - i.pos_WS);
                half4 NdotV = saturate(dot(i.normal_WS, viewDir));
                half4 Fresnel = pow(1 - NdotV, _PowStr);
                half2 uv_Ramp = half2(Fresnel.x, 0.5);

            #ifdef _Rampcheck_ON
                half4 ramp_Col = tex2D(_RampTex, uv_Ramp);
            #else
                half4 ramp_Col = 1;
            #endif
                
                half4 mainTex = tex2D(_MainTex, i.uv);

                float4 finalCol = Matcap * mainTex * ramp_Col + MatcapAdd;
                return finalCol;
            }
            ENDCG
        }
    }
}