Shader "Unlit/LightingRender"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _AoMap ("AO图", 2D) = "white" {}
        _SpecMask ("高光蒙版", 2D) = "white" {}
        _NormalMap ("法线贴图", 2D) = "bump" {}
        _HightMap ("高度图", 2D) = "bump" {}
        _NormalIntensity ("法线强度", Float) = 1
        //_MainLightColor ("主光色", Color) = (1,1,1,1)

        _Gloss ("高光集中度", Range(1,100)) = 1
        _SpecIntensity ("高光亮度", Float) = 1
        _HeightScale ("高度", Float) = 1
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
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

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
                float3 normalDir_WS : TEXCOORD1;
                float3 pos_WS : TEXCOORD2;
                float3 tangentDir_WS : TEXCOORD3;
                float3 bitangentDir_WS : TEXCOORD4;
                UNITY_SHADOW_COORDS(5)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _AoMap;
            float4 _AoMap_ST;
            sampler2D _SpecMask;
            float4 _SpecMask_ST;
            sampler2D _NormalMap;
            float4 _NormalMap_ST;
            sampler2D _HightMap;
            float4 _HightMap_ST;

            float4 _LightColor0;
            float _Gloss;
            float _SpecIntensity;
            float _NormalIntensity;
            float _HeightScale;

            float3 ACESFilm(float3 x)
            {
                float a = 2.51f;
                float b = 0.03f;
                float c = 2.43f;
                float d = 0.59f;
                float e = 0.14f;
                return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos_WS = mul(unity_ObjectToWorld, v.vertex);
                o.normalDir_WS = UnityObjectToWorldNormal(v.normal);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.tangentDir_WS = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.bitangentDir_WS = normalize(cross(o.normalDir_WS, o.tangentDir_WS)) * v.tangent.w;
                // v.tangent.w处理不同平台副切线的翻转问题
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                //                UNITY_TRANSFER_SHADOW(o, v.uv);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half shadow = LIGHT_ATTENUATION(i);
                half3 viewDir_WS = normalize(_WorldSpaceCameraPos.xyz - i.pos_WS);
                ///normalMap
                half3 normal_Dir = normalize(i.normalDir_WS); //法线方向，垂直于表面
                half3 tangent_Dir = normalize(i.tangentDir_WS); //切线方向，通常是 UV 的 U 方向
                half3 bitangent_Dir = normalize(i.bitangentDir_WS); //副切线方向，通常是 UV 的 V 方向
                float3x3 TBN = float3x3(tangent_Dir, bitangent_Dir, normal_Dir);
                half3 viewDir_Tangent = normalize(mul(TBN, viewDir_WS)); //获得切线空间下的观察方向
                half2 uv_Offset = i.uv;
                for (int j = 0; j < 10; j++) // 一般使用一两次，而且不会写for循环，费性能
                {
                    half height = tex2D(_HightMap, uv_Offset); //从高度图获取当前点的高度（0~1）          注意Tex2D的使用数量，7-8个就很耗了，降低采样次数
                    uv_Offset = uv_Offset - (0.5 - height) * viewDir_Tangent.xy * _HeightScale * 0.01f;
                    //用减法就深度，_HeightScale值越大对高度图黑色区域下陷程度越大
                }

                half4 mainTex = tex2D(_MainTex, uv_Offset);
                mainTex = pow(mainTex, 2.2);
                half4 aoTex = tex2D(_AoMap, uv_Offset);
                half4 specMaskTex = tex2D(_SpecMask, uv_Offset);
                half4 normalMap = tex2D(_NormalMap, uv_Offset); //法线贴图通常存储的是归一化后的值（范围 [0, 1]），但实际计算时需要映射到 [-1, 1] 先解码
                half3 normal_Data = UnpackNormal(normalMap); // 解码
                normal_Data.xy = normal_Data.xy * _NormalIntensity;

                normal_Dir = mul(normal_Data, TBN);
                half3 light_Dir = normalize(_WorldSpaceLightPos0.xyz);
                half3 half_Dir = normalize(light_Dir + viewDir_WS); // 半程向量方向（Buling-Phone高光模型使用）

                half NdotL = dot(normal_Dir, light_Dir);
                half NdotH = dot(normal_Dir, half_Dir);

                half3 diff_term = min(shadow, max(0, NdotL));
                half3 halfLambert_Col = diff_term * _LightColor0.xyz * mainTex.rgb;
                half3 bulingPhone_Col = pow(max(0, NdotH), _Gloss) * diff_term * _LightColor0.xyz * _SpecIntensity *
                    specMaskTex.rgb;
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb * mainTex.rgb;

                float3 finnal_Col = (halfLambert_Col + bulingPhone_Col + ambient) * aoTex;
                half3 tone_Col = ACESFilm(finnal_Col); //色调映射技术是在后处理阶段做的，如果提前在这里做了就把亮度范围限制到0-1了，后续做不了辉光效果
                tone_Col = pow(tone_Col, 1.0 / 2.2);
                return float4(tone_Col, 1);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}