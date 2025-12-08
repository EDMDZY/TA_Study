Shader "Unlit/HairRender"
{
    Properties
    {
        // 基础属性
        _BaseMap ("基础贴图", 2D) = "white" {}
        _BaseColor ("基础颜色", Color) = (1,1,1,1)
        _NormalMap ("法线贴图", 2D) = "bump" {}

        // 高光属性
        [Header(Specular)]
        _AnisoMap ("各向异性噪波图", 2D) = "white" {} // 用于添加高光不规则性
        _SpecularColor1 ("第一层高光颜色", Color) = (1,1,1,1)
        _specNoise1 ("第一层高光噪波强度", Float) = 1
        _SpecShininess1 ("第一层高光锐度", Range(0, 1)) = 0.2
        _SpecOffset1("第一层高光偏移", Float) = 0

        _SpecularColor2 ("第二层高光颜色", Color) = (1,1,1,1)
        _specNoise2 ("第二层高光噪波强度", Float) = 0.5
        _SpecShininess2 ("第二层高光锐度", Range(0, 1)) = 0.07
        _SpecOffset2("第二层高光偏移", Float) = 0

        // 环境反射属性
        [Header(Image Based Lighting)]
        _CubeMap ("环境立方体贴图", Cube) = "bump" {}
        _Expose ("环境光曝光", Float) = 0.32
        _Rotate ("环境贴图旋转", Range(0,360)) = 0
        _RoughnessAdjust ("粗糙度调整", Range(-1, 1)) = 0.21

        // 调试开关
        [Toggle(_DIFFUSECHECK_ON)] _Diffusecheck("漫反射开关", Float) = 1
        [Toggle(_SPECLUARCHECK_ON)] _Specularcheck("高光开关", Float) = 1
        [Toggle(_IBLCHECK_ON)] _IBLcheck("环境反射开关", Float) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" // 渲染类型为不透明
            "LightMode"="ForwardBase" // 使用前向渲染基础光照
        }
        LOD 100 // 细节级别

        Pass
        {
            CGPROGRAM
            #pragma vertex vert  // 顶点着色器
            #pragma fragment frag  // 片段着色器
            #pragma multi_compile_fwdbase  // 编译多种前向基础光照变体
            #pragma shader_feature _DIFFUSECHECK_ON  // 漫反射开关
            #pragma shader_feature _SPECLUARCHECK_ON  // 高光开关
            #pragma shader_feature _IBLCHECK_ON  // 环境反射开关

            #include "UnityCG.cginc"  // Unity CG包含文件
            #include "AutoLight.cginc"  // 自动光照包含文件

            // 顶点着色器输入结构
            struct appdata
            {
                float4 vertex : POSITION; // 顶点位置
                float2 uv : TEXCOORD0; // 纹理坐标
                float3 normal : NORMAL; // 法线
                float4 tangent : TANGENT; // 切线
            };

            // 顶点到片段着色器的传递结构
            struct v2f
            {
                float2 uv : TEXCOORD0; // 纹理坐标
                float4 vertex : SV_POSITION; // 裁剪空间位置
                float3 normal_world : TEXCOORD1; // 世界空间法线
                float3 pos_world : TEXCOORD2; // 世界空间位置
                float3 tangent_world : TEXCOORD3; // 世界空间切线
                float3 binormal_world : TEXCOORD4; // 世界空间副切线
                LIGHTING_COORDS(5, 6) // 光照衰减坐标
            };

            // 贴图与颜色属性
            sampler2D _BaseMap; // 基础颜色贴图
            sampler2D _NormalMap; // 法线贴图
            float4 _LightColor0; // 主光源颜色

            // 高光属性
            sampler2D _AnisoMap; // 各向异性噪波图
            float4 _AnisoMap_ST; // 噪波图的缩放和偏移
            float4 _SpecularColor1; // 第一层高光颜色
            float _specNoise1; // 第一层噪波强度
            float _SpecShininess1; // 第一层高光锐度
            float _SpecOffset1; // 第一层高光偏移
            float4 _SpecularColor2; // 第二层高光颜色
            float _specNoise2; // 第二层噪波强度
            float _SpecShininess2; // 第二层高光锐度
            float _SpecOffset2; // 第二层高光偏移

            // 环境反射属性
            samplerCUBE _CubeMap; // 环境立方体贴图
            float4 _CubeMap_HDR; // HDR环境贴图数据
            float _Expose; // 环境光曝光
            float _Rotate; // 环境贴图旋转
            float _RoughnessAdjust; // 粗糙度调整

            // ACES色调映射函数
            inline float3 ACES_Tonemapping(float3 x)
            {
                float a = 2.51f;
                float b = 0.03f;
                float c = 2.43f;
                float d = 0.59f;
                float e = 0.14f;
                float3 encode_color = saturate((x * (a * x + b)) / (x * (c * x + d) + e));
                return encode_color;
            };

            // 环境贴图旋转函数
            float3 RotateAround(float degree, float3 target)
            {
                float rad = degree * UNITY_PI / 180;
                float2x2 m_rotate = float2x2(cos(rad), -sin(rad),sin(rad), cos(rad));
                float2 dir_rotate = mul(m_rotate, target.xz);
                target = float3(dir_rotate.x, target.y, dir_rotate.y);
                return target;
            }

            // 顶点着色器
            v2f vert(appdata v)
            {
                v2f o;
                // 顶点位置转换到裁剪空间
                o.vertex = UnityObjectToClipPos(v.vertex);
                // 传递纹理坐标
                o.uv = v.uv;
                // 计算世界空间位置
                o.pos_world = mul(unity_ObjectToWorld, v.vertex).xyz;
                // 计算世界空间法线
                o.normal_world = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz);
                // 计算世界空间切线
                o.tangent_world = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                // 计算世界空间副切线
                o.binormal_world = normalize(cross(o.normal_world, o.tangent_world)) * v.tangent.w;
                // 传递光照衰减数据(注释掉因为需要TRANSFER_VERTEX_TO_FRAGMENT宏)
                // TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            // 片段着色器
            half4 frag(v2f i) : SV_Target
            {
                // ========== 贴图数据获取 ==========
                // 基础颜色(伽马空间)
                half4 baseColor_gama = tex2D(_BaseMap, i.uv);
                // 转换到线性空间
                half3 baseColor = pow(baseColor_gama, 2.2);
                half roughness = saturate(_RoughnessAdjust);

                // 解码法线贴图
                half3 normaldata = UnpackNormal(tex2D(_NormalMap, i.uv));

                // ========== 构建TBN矩阵 ==========
                half3 tangent_dir = normalize(i.tangent_world);
                half3 binormal_dir = normalize(i.binormal_world);
                half3 normal_dir = normalize(i.normal_world);
                float3x3 TBN = float3x3(tangent_dir, binormal_dir, normal_dir);
                // 转换法线到世界空间
                normal_dir = mul(normaldata, TBN);

                // ========== 向量准备 ==========
                // 观察方向(相机到表面)
                half3 view_Dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);
                // 光照方向
                half3 light_Dir = normalize(_WorldSpaceLightPos0.xyz);
                // 光照衰减
                half atten = LIGHT_ATTENUATION(i);
                // 半角向量
                half3 half_Dir = normalize(light_Dir + view_Dir);
                // 反射方向
                half3 reflect_dir = reflect(-view_Dir, normal_dir);

                // 点积计算
                half NdotL = max(0, dot(normal_dir, light_Dir)); // 法线与光方向
                half NdotH = dot(normal_dir, half_Dir); // 法线与半角向量

                // ========== 直接光漫反射 ==========
                half halfLambert = NdotL * 0.5 + 0.5; // 半兰伯特
                #ifdef _DIFFUSECHECK_ON
                half3 direct_diffuse = baseColor.xyz; // 基础颜色作为漫反射
                #else
            		half3 direct_diffuse = half3(0,0,0);  // 关闭漫反射
                #endif

                // ========== 直接光镜面反射(各向异性高光) ==========
                // 采样各向异性噪波图
                half2 uv_aniso = i.uv * _AnisoMap_ST.xy + _AnisoMap_ST.zw;
                half aniso_noise = tex2D(_AnisoMap, uv_aniso).r - 0.5; // 转换到[-0.5,0.5]

                // 计算切线点积
                half TdotH = dot(tangent_dir, half_Dir);
                half NdotV = max(0, dot(normal_dir, view_Dir));

                // 各向异性衰减
                float aniso_attn = saturate(sqrt(max(0, halfLambert / NdotV))) * atten;

                // 第一层高光
                float3 spec_color1 = _SpecularColor1 + baseColor; // 高光颜色混合基础色
                float3 aniso_offset1 = normal_dir * (aniso_noise * _specNoise1 + _SpecOffset1); // 计算偏移
                float3 binormal_dir1 = normalize(binormal_dir + aniso_offset1); // 偏移副切线
                float BdotH1 = dot(half_Dir, binormal_dir1) / _SpecShininess1; // 副切线点积
                float3 spec_term1 = exp(-(TdotH * TdotH + BdotH1 * BdotH1) / (1 + NdotH)); // 高光项
                float3 final_spec1 = spec_term1 * spec_color1 * _LightColor0; // 最终高光1

                // 第二层高光
                float3 spec_color2 = _SpecularColor2 + baseColor;
                float3 aniso_offset2 = normal_dir * (aniso_noise * _specNoise2 + _SpecOffset2);
                float3 binormal_dir2 = normalize(binormal_dir + aniso_offset2);
                float BdotH2 = dot(half_Dir, binormal_dir2) / _SpecShininess2;
                float3 spec_term2 = exp(-(TdotH * TdotH + BdotH2 * BdotH2) / (1 + NdotH));
                float3 final_spec2 = spec_term2 * spec_color2 * _LightColor0;

                // 合并高光
                #ifdef _SPECLUARCHECK_ON
                half3 direct_specular = final_spec1 + final_spec2; // 启用高光
                #else
            		half3 direct_specular = half3(0,0,0);  // 关闭高光
                #endif

                // ========== 间接光镜面反射(IBL) ==========
                // 调整粗糙度
                roughness = roughness * (1.7 - 0.7 * roughness);
                // 根据粗糙度选择mip级别
                float mip_level = roughness * 6.0;
                // 采样环境贴图
                half4 color_cubemap = texCUBElod(_CubeMap, float4(reflect_dir, mip_level));
                // 解码HDR并应用曝光
                #ifdef _IBLCHECK_ON
                half3 env_specular = DecodeHDR(color_cubemap, _CubeMap_HDR) * _Expose * aniso_noise * halfLambert;
                #else
            		half3 env_specular = half3(0,0,0);  // 关闭环境反射
                #endif

                // ========== 最终光照合成 ==========
                float3 finnal_Col = direct_specular + env_specular + direct_diffuse;
                // 色调映射
                finnal_Col = ACES_Tonemapping(finnal_Col);
                // 转换回伽马空间
                finnal_Col = pow(finnal_Col, 1 / 2.2);

                return float4(finnal_Col, 1);
            }
            ENDCG
        }
    }
    Fallback "Diffuse" // 后备着色器
}