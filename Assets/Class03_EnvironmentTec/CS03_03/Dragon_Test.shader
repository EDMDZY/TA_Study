Shader "Unlit/Dragon_Test"
{
    Properties
    {
        _ThicknessMap("Thickness Map厚度图",2D) = "black"{}
        _CubeMap("反射贴图", Cube) = "white"{}
        _BaseCol ("基础色", Color) = (1,1,1,1)
        _BackLightCol ("_BackLightCol透射光颜色", Color) = (1,1,1,1)
        _Distort ("_Distort扭曲度", Range(0, 1)) = 0.29
        _Pow ("_pow透光度", Range(0, 20)) = 3.6
        _Scale ("_scale透光强度", Range(0, 10)) = 1.82
        _FresnelCol ("_FresnelCol菲涅尔颜色", Color) = (1,1,1,1)
        _FresnelStr ("菲涅尔强度", Range(0.01, 2)) = 0.17
        _EnvRotate ("高光反射角度", Range(0, 360)) = 133
        _EnvIntensity("反射强度", Range(0, 2)) = 0.27
    }
    SubShader
    {
        Pass
        {
            Tags { "LightMode"="ForwardBase"}
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
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 pos_WS : TEXCOORD1;
                float3 normalDir_WS : TEXCOORD2;
            };

            sampler2D _ThicknessMap;
            float4 _ThicknessMap_ST;
            samplerCUBE _CubeMap;
            float4 _CubeMap_HDR;
            float4 _BaseCol;
            float4 _FresnelCol;
            float _Distort;
            float _Pow;
            float _Scale;
            float _FresnelStr;
            float _EnvRotate;
            float _EnvIntensity;
            float4 _BackLightCol;
            float4 _LightColor0;

            float3 RotateAround(float degree, float3 target)
            {
                float rad = degree * UNITY_PI / 180;
                float2x2 m_rotate = float2x2(cos(rad), -sin(rad),
                   sin(rad), cos(rad));
                float2 dir_rotate = mul(m_rotate, target.xz);
                target = float3(dir_rotate.x, target.y, dir_rotate.y);
                return target;
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.pos_WS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normalDir_WS = UnityObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                half3 normal_WS = normalize(i.normalDir_WS);
                half3 viewDir_WS = normalize(_WorldSpaceCameraPos.xyz - i.pos_WS);
                half3 lightDir = normalize(_WorldSpaceLightPos0.xyz);

                // 透射光
                half3 LmixN_Dir = -normalize(lightDir + normal_WS * _Distort);     // 光线加法线方向偏移可以在后续与观察方向计算时让模型有空间感
                half VdotL = max(0, dot(viewDir_WS, LmixN_Dir));       						 // 当视线和光线有夹角时才能看见光
                half throughLight = max(0, pow(VdotL, _Pow)) * _Scale;
                half thickmap = 1 - tex2D(_ThicknessMap, i.uv).r;									 
                half3 backLight = throughLight * thickmap * _BackLightCol;

                // 光泽反射
                half3 reflectDir = reflect(-viewDir_WS, normal_WS);
                reflectDir = RotateAround(_EnvRotate, reflectDir);
                half4 color_cubemap = texCUBE(_CubeMap, reflectDir);
                half3 fresnel = (1 - pow(max(0, dot(normal_WS, viewDir_WS)), _FresnelStr)) * _FresnelCol;
                half3 reflect_color = DecodeHDR(color_cubemap, _CubeMap_HDR) * _EnvIntensity;
                
                
                half3 finalColor = backLight + reflect_color + _BaseCol + fresnel;
               
                return float4(finalColor, 1);
            }
            ENDCG
        }
    }
}