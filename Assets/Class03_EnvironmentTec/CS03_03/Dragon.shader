Shader "Dragon" {
   Properties {
        // 基础颜色
        _DiffuseColor("漫反射颜色", Color) = (0, 0.352, 0.219, 1)
        _AddColor("附加颜色", Color) = (0, 0.352, 0.219, 1)
        _Opacity("不透明度", Range(0, 1)) = 0  // 用于控制天空光的透明度
        _ThicknessMap("厚度贴图", 2D) = "black"{}  // 用于控制透光效果的厚度信息，黑色区域更薄
        
        // BasePass设置区域
        [Header(BasePass)]
        _BasePassDistortion("BasePass扭曲度", Range(0, 1)) = 0.2  // 主通道的透射光扭曲程度
        _BasePassColor("BasePass颜色", Color) = (1, 1, 1, 1)  // 主通道透射光颜色
        _BasePassPower("BasePass次方数", float) = 1  // 透射光衰减曲线
        _BasePassScale("BasePass缩放", float) = 2  // 透射光强度
        
        // AddPass设置区域
        [Header(AddPass)]
        _AddPassDistortion("AddPass扭曲度", Range(0, 1)) = 0.2  // 附加通道的透射光扭曲程度
        _AddPassColor("AddPass颜色", Color) = (0.56, 0.647, 0.509, 1)  // 附加通道透射光颜色
        _AddPassPower("AddPass次方数", float) = 1  // 附加通道透射光衰减曲线
        _AddPassScale("AddPass缩放", float) = 1  // 附加通道透射光强度
        
        // 环境反射设置区域
        [Header(EnvReflect)]
        _EnvRotate("环境贴图旋转角度", Range(0, 360)) = 0  // 旋转环境贴图
        _EnvMap("环境贴图", Cube) = "white" {}  // 立方体贴图用于环境反射
        _FresnelMin("菲涅尔最小值", Range(-2, 2)) = 0  // 菲涅尔效果的最小值
        _FresnelMax("菲涅尔最大值", Range(-2, 2)) = 1  // 菲涅尔效果的最大值
        _EnvIntensity("环境反射强度", float) = 1.0  // 环境反射的强度
   }
   
   SubShader {
        // 第一个Pass：BasePass（基础光照通道）
        Pass {
            Tags { "LightMode" = "ForwardBase" }  // 指定为前向渲染的基础通道，处理主方向光和所有一次性计算的光照
            CGPROGRAM
            
            // 编译指令
            #pragma vertex vert  // 指定顶点着色器函数
            #pragma fragment frag  // 指定片元着色器函数
            #pragma multi_compile_fwdbase  // 编译前向渲染基础通道的变体
            
            // 包含文件
            #include "UnityCG.cginc"  // Unity内置的CG函数和宏
            #include "AutoLight.cginc"  // 光照相关函数和宏
            
            // 纹理和属性声明
            sampler2D _ThicknessMap;  // 厚度贴图
            float4 _DiffuseColor;  // 漫反射颜色
            float4 _AddColor;  // 附加颜色
            float _Opacity;  // 不透明度
            
            // BasePass透射光属性
            float4 _BasePassColor;
            float _BasePassDistortion;
            float _BasePassPower;
            float _BasePassScale;
            
            // 环境反射属性
            samplerCUBE _EnvMap;  // 环境立方体贴图
            float4 _EnvMap_HDR;  // HDR环境贴图信息
            float _EnvRotate;  // 环境贴图旋转角度
            float _EnvIntensity;  // 环境反射强度
            float _FresnelMin;  // 菲涅尔最小值
            float _FresnelMax;  // 菲涅尔最大值
            
            // Unity内置光照属性
            float4 _LightColor0;  // 主光源颜色
            
            // 顶点着色器输入结构
            struct appdata {
                float4 vertex : POSITION;  // 顶点位置
                float2 texcoord : TEXCOORD0;  // 纹理坐标
                float3 normal : NORMAL;  // 法线
            };
            
            // 顶点着色器输出/片元着色器输入结构
            struct v2f {
                float4 pos : SV_POSITION;  // 裁剪空间位置
                float2 uv : TEXCOORD0;  // 纹理坐标
                float4 posWorld : TEXCOORD1;  // 世界空间位置
                float3 normalDir : TEXCOORD2;  // 世界空间法线方向
            };
            
            // 顶点着色器函数
            v2f vert(appdata v)
            {
                v2f o;  // 输出变量
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);  // 转换到世界空间
                o.normalDir = UnityObjectToWorldNormal(v.normal);  // 转换法线到世界空间
                o.uv = v.texcoord;  // 传递纹理坐标
                o.pos = UnityObjectToClipPos(v.vertex);  // 转换到裁剪空间
                return o;
            }
            
            // 片元着色器函数
            float4 frag(v2f i) : COLOR
            {
                // 基础信息
                float3 diffuse_color = _DiffuseColor;  // 获取漫反射颜色
                float3 normalDir = normalize(i.normalDir);  // 归一化法线方向
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.posWorld.xyz);  // 计算观察方向
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);  // 主光源方向
                
                // 漫反射光照计算
                float diff_term = max(0.0, dot(normalDir, lightDir));  // 兰伯特漫反射项
                float3 diffuselight_color = diff_term * diffuse_color * _LightColor0.rgb;  // 漫反射光照颜色
                
                // 天空球光照计算（模拟环境光）
                float sky_sphere = (dot(normalDir, float3(0, 1, 0)) + 1.0) * 0.5;  // 基于Y轴的环境光
                float3 sky_light = sky_sphere * diffuse_color;  // 天空光颜色
                float3 final_diffuse = diffuselight_color + sky_light * _Opacity + _AddColor.xyz;  // 最终的漫反射
                
                // 透射光计算（背光效果）
                float3 back_dir = -normalize(lightDir + normalDir * _BasePassDistortion);  // 计算扭曲后的背光方向
                float VdotB = max(0.0, dot(viewDir, back_dir));  // 视线与背光方向的点积
                float backlight_term = max(0.0, pow(VdotB, _BasePassPower)) * _BasePassScale;  // 背光项
                float thickness = 1.0 - tex2D(_ThicknessMap, i.uv).r;  // 采样厚度贴图，白色=薄，黑色=厚
                float3 backlight = backlight_term * thickness * _LightColor0.xyz * _BasePassColor.xyz;  // 背光颜色
                
                // 环境反射计算
                float3 reflectDir = reflect(-viewDir, normalDir);  // 计算反射方向
                
                // 环境贴图旋转
                half theta = _EnvRotate * UNITY_PI / 180.0f;  // 角度转弧度
                float2x2 m_rot = float2x2(cos(theta), -sin(theta), sin(theta), cos(theta));  // 创建2D旋转矩阵
                float2 v_rot = mul(m_rot, reflectDir.xz);  // 旋转反射方向
                reflectDir = half3(v_rot.x, reflectDir.y, v_rot.y);  // 更新反射方向
                
                // 采样环境贴图
                float4 cubemap_color = texCUBE(_EnvMap, reflectDir);  // 采样立方体贴图
                half3 env_color = DecodeHDR(cubemap_color, _EnvMap_HDR);  // 解码HDR颜色
                
                // 菲涅尔效果
                float fresnel = 1.0 - saturate(dot(normalDir, viewDir));  // 计算菲涅尔系数
                fresnel = smoothstep(_FresnelMin, _FresnelMax, fresnel);  // 平滑菲涅尔值
                
                // 最终的环境反射
                float3 final_env = env_color * _EnvIntensity * fresnel;  // 应用强度和菲涅尔
                
                // 组合所有光照
                float3 combined_color = final_diffuse + final_env + backlight;  // 组合漫反射、环境反射和背光
                float3 final_color = combined_color;  // 最终颜色
                
                return float4(final_color, 1.0);  // 输出颜色
            }
            ENDCG
        }
        
        // 第二个Pass：AddPass（附加光照通道）
        Pass {
            Tags { "LightMode" = "ForwardAdd" }  // 指定为前向渲染的附加通道，处理额外的光源
            Blend One One  // 使用加法混合模式（One One）
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdadd  // 编译前向渲染附加通道的变体
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            
            // 光照和属性声明
            float4 _LightColor0;  // 当前光源颜色
            
            float4 _DiffuseColor;  // 漫反射颜色
            sampler2D _ThicknessMap;  // 厚度贴图
            float _AddPassDistortion;  // AddPass扭曲度
            float _AddPassPower;  // AddPass次方数
            float _AddPassScale;  // AddPass缩放
            float4 _AddPassColor;  // AddPass颜色
            
            // 顶点着色器输入结构
            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 texcoord0 : TEXCOORD0;
            };
            
            // 顶点着色器输出/片元着色器输入结构
            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 posWorld : TEXCOORD1;
                float3 normalDir : TEXCOORD2;
                LIGHTING_COORDS(5, 6)  // 光照贴图坐标宏
            };
            
            // 顶点着色器函数
            v2f vert(appdata v)
            {
                v2f o;  // 输出变量
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);  // 转换到世界空间
                o.normalDir = UnityObjectToWorldNormal(v.normal);  // 转换法线到世界空间
                o.uv = v.texcoord0;  // 传递纹理坐标
                o.pos = UnityObjectToClipPos(v.vertex);  // 转换到裁剪空间
                TRANSFER_VERTEX_TO_FRAGMENT(o);  // 传递光照信息到片元着色器
                return o;
            }
            
            // 片元着色器函数
            float4 frag(v2f i) : COLOR
            {
                // 计算方向
                float3 normalDir = normalize(i.normalDir);  // 归一化法线方向
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.posWorld.xyz);  // 计算观察方向
                
                // 计算光源方向（考虑平行光和点光源）
                // 对于平行光，w=0；对于点光源，w=1
                float3 lightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, 
                                                _WorldSpaceLightPos0.xyz - i.posWorld.xyz, 
                                                _WorldSpaceLightPos0.w));
                
                // 透射光计算
                float3 back_dir = -normalize(lightDir + normalDir * _AddPassDistortion);  // 计算扭曲后的背光方向
                float VdotB = max(0.0, dot(viewDir, back_dir));  // 视线与背光方向的点积
                float backlight_term = max(0.0, pow(VdotB, _AddPassPower)) * _AddPassScale;  // 背光项
                float thickness = 1.0 - tex2D(_ThicknessMap, i.uv).r;  // 采样厚度贴图
                float3 backlight = backlight_term * thickness * _LightColor0.xyz * _AddPassColor.xyz;  // 背光颜色
                
                // 组合结果
                float3 final_color = backlight;  // 只包含背光
                final_color = sqrt(final_color);  // 应用gamma校正（近似）
                return float4(final_color, 1.0);  // 输出颜色
            }
            ENDCG
        }
   }
   FallBack "Diffuse"  // 如果硬件不支持，回退到标准漫反射着色器
}