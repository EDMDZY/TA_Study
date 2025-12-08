Shader "Unlit/RoleRender"
{
    Properties
    {
        _BaseMap ("_BaseMap", 2D) = "white" {}
        _CompMask ("_CompMask", 2D) = "white" {}
        _NormalMap ("_NormalMap", 2D) = "bump" {}
	    _SpecShininess ("_SpecShininess", Float) = 1
    	
	    [Header(SSS)]
	    _SSSMap ("SSSMap", 2D) = "white" {}
	    _SSSOffset ("SSS Offset", Range(0.51,0.99)) = 0.99
	    
	    [Header(IBL)]
		_CubeMap ("_CubeMap", Cube) = "bump" {}
		_Expose ("Expose",Float) = 1.0
		_Rotate ("Rotate",Range(0,360)) = 0
	    _RoughnessAdjust ("_RoughnessAdjust", Range(-1, 1)) = 0
	    _MetalAdjust ("_MetalAdjust", Range(-1, 1)) = 0
	    _SkinLightInstensity ("_SkinLightInstensity", Range(0, 0.5)) = 0.1
	    
	    [Toggle(_DIFFUSECHECK_ON)] _Diffusecheck("Diffuse Check", Float) = 1
	    [Toggle(_SPECLUARCHECK_ON)] _Specularcheck("Specluar Check", Float) = 1
	    [Toggle(_SHCHECK_ON)] _SHcheck("SH Check", Float) = 1
	    [Toggle(_IBLCHECK_ON)] _IBLcheck("IBL Check", Float) = 1
	    
	    [HideInInspector]custom_SHAr("Custom SHAr", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHAg("Custom SHAg", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHAb("Custom SHAb", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHBr("Custom SHBr", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHBg("Custom SHBg", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHBb("Custom SHBb", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHC("Custom SHC", Vector) = (0, 0, 0, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"}
        LOD 100

        Pass
        {
        	Tags { "LightMode"="ForwardBase"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma multi_compile_fwdbase
            #pragma shader_feature _DIFFUSECHECK_ON		// 直接光漫反射开关
            #pragma shader_feature _SPECLUARCHECK_ON	// 直接光镜面反射开关
            #pragma shader_feature _SHCHECK_ON			// 间接光漫反射开关（SH）
            #pragma shader_feature _IBLCHECK_ON			// 间接光镜面反射开关（IBL）

            #include "UnityCG.cginc"
			#include "AutoLight.cginc"
						
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
				float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal_world : TEXCOORD1;
				float3 pos_world : TEXCOORD2;
				float3 tangent_world : TEXCOORD3;
				float3 binormal_world : TEXCOORD4;
	            LIGHTING_COORDS(5, 6)
            };

            sampler2D _BaseMap;
			sampler2D _CompMask;
            sampler2D _NormalMap;
            
            float4 _LightColor0;
            float _SpecShininess;

            //SSS
            sampler2D _SSSMap;
            float _SSSOffset;
            
						//sh
            half4 custom_SHAr;
			half4 custom_SHAg;
			half4 custom_SHAb;
			half4 custom_SHBr;
			half4 custom_SHBg;
			half4 custom_SHBb;
			half4 custom_SHC;

            //IBL
            samplerCUBE _CubeMap;
            float4 _CubeMap_HDR;
			float _Expose;
            float _Rotate;
            float _RoughnessAdjust;
            float _MetalAdjust;
            float _SkinLightInstensity;

			inline float3 ACES_Tonemapping(float3 x)
			{
				float a = 2.51f;
				float b = 0.03f;
				float c = 2.43f;
				float d = 0.59f;
				float e = 0.14f;
				float3 encode_color = saturate((x*(a*x + b)) / (x*(c*x + d) + e));
				return encode_color;
			};
			
			float3 RotateAround(float degree, float3 target)
			{
				float rad = degree * UNITY_PI / 180;
				float2x2 m_rotate = float2x2(cos(rad), -sin(rad),sin(rad), cos(rad));
				float2 dir_rotate = mul(m_rotate, target.xz);
				target = float3(dir_rotate.x, target.y, dir_rotate.y);
				return target;
			}

            // 球谐（sh）光照（间接光漫反射）
            float3 custom_sh(float3 normalDir)
            {
            	float4 normalForSH = float4(normalDir, 1.0);
	            //SHEvalLinearL0L1
				half3 x;
				x.r = dot(custom_SHAr, normalForSH);
				x.g = dot(custom_SHAg, normalForSH);
				x.b = dot(custom_SHAb, normalForSH);
			
				//SHEvalLinearL2
				half3 x1, x2;
				// 4 of the quadratic (L2) polynomials
				half4 vB = normalForSH.xyzz * normalForSH.yzzx;
				x1.r = dot(custom_SHBr, vB);
				x1.g = dot(custom_SHBg, vB);
				x1.b = dot(custom_SHBb, vB);
			
				// Final (5th) quadratic (L2) polynomial
				half vC = normalForSH.x*normalForSH.x - normalForSH.y*normalForSH.y;
				x2 = custom_SHC.rgb * vC;
			
				float3 sh = max(float3(0.0, 0.0, 0.0), (x + x1 + x2));
				sh = pow(sh, 1.0 / 2.2);
            	return sh;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.pos_world = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.normal_world = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz);
				o.tangent_world = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
				o.binormal_world = normalize(cross(o.normal_world, o.tangent_world)) * v.tangent.w;
	            //TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // 贴图数据获取
                half4 baseColor_gama = tex2D(_BaseMap, i.uv);	// 纹理一般存在伽马空间内
	            half4 albedo_color = pow(baseColor_gama, 2.2);	// 线性空间转换	因为物理光照计算应该在线性空间进行才符合现实物理规律
                half4 compMask = tex2D(_CompMask, i.uv);		// r通道是粗糙图，g是金属度图，b是皮肤部分
	            half roughness = saturate(compMask.r + _RoughnessAdjust);
	            half metal = saturate(compMask.g + _MetalAdjust);						// 金属图全白为1 金属部分
	            half skin_area = 1 - compMask.b;										// 皮肤部分			
	            half3 baseColor = albedo_color.rgb * (1 - metal);	// 非金属固有色
	            half3 specColor = lerp(0, albedo_color.rgb, metal);	// 高光颜色（0.04为经验值）
            	
                half3 normaldata = UnpackNormal(tex2D(_NormalMap,i.uv));	// 解码得到法线贴图数据信息
            	
				// 构建TBN矩阵
				half3 tangent_dir = normalize(i.tangent_world);
				half3 binormal_dir = normalize(i.binormal_world);
				half3 normal_dir = normalize(i.normal_world);
				float3x3 TBN = float3x3(tangent_dir, binormal_dir, normal_dir);
				// 通过TBN矩阵转换法线数据得到新的法线方向
				normal_dir = mul(normaldata, TBN);

	            // 向量准备
	            half3 view_Dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);					// 观察方向
                half3 light_Dir = normalize(_WorldSpaceLightPos0.xyz);								// 光照方向
                half3 half_Dir = normalize(light_Dir + view_Dir);                  					// 半程向量方向（Buling-Phone高光模型使用）
	            half3 reflect_dir = reflect(-view_Dir, normal_dir);
                
                half NdotL = max(0, dot(normal_dir, light_Dir));
	            half halfLambert = NdotL * 0.5 + 0.5;										
                half NdotH = dot(normal_dir, half_Dir);
            	half attn = LIGHT_ATTENUATION(i);

            #ifdef _DIFFUSECHECK_ON
                // Direct Diffuse直接光漫反射
                half3 Common_diffuse = NdotL * _LightColor0.xyz * baseColor.xyz;		
            	
	            half2 skin_uv = half2(halfLambert + _SSSOffset, 1);
	            half3 skin_color_gama = tex2D(_SSSMap, skin_uv);
	            half3 skin_color = pow(skin_color_gama, 2.2);
				half3 sss_diffuse = skin_color * _LightColor0.xyz * baseColor.xyz * NdotL;
            	
	            half3 direct_diffuse = lerp(Common_diffuse, sss_diffuse, skin_area);
			#else
	            half3 direct_diffuse = half3(0,0,0);
            #endif

            #ifdef _SPECLUARCHECK_ON	
	            // Direct Specular直接光镜面反射
	            half smoothness = 1 - roughness;
	            half shininess = lerp(1, _SpecShininess, smoothness);
                half direct_term = pow(max(0, NdotH), shininess * smoothness);

	            half3 spec_skin_color = lerp(specColor, _SkinLightInstensity, skin_area);		// 皮肤高光
                half3 direct_specular = direct_term * spec_skin_color * _LightColor0;					
			#else
	            half3 direct_specular = half3(0,0,0);
            #endif

            #ifdef _SHCHECK_ON	
	            // 阴影不算进间接光中，因为间接光需要用来提亮暗部阴影
	            // 间接光漫反射（sh）
	            float3 env_diffuse = custom_sh(normal_dir) * baseColor * halfLambert;
	            env_diffuse = lerp(env_diffuse * 0.5, env_diffuse , skin_area);
			#else
	            half3 env_diffuse = half3(0,0,0);
            #endif

            #ifdef _IBLCHECK_ON	
	            // 间接光镜面反射（IBL）
	            reflect_dir = RotateAround(_Rotate, reflect_dir);
	            roughness = roughness * (1.7 - 0.7 * roughness);
				float mip_level = roughness * 6.0;
	            half4 color_cubemap = texCUBElod(_CubeMap, float4(reflect_dir, mip_level));
				half3 env_specular = DecodeHDR(color_cubemap, _CubeMap_HDR) * specColor * _Expose * halfLambert;
			#else
	            half3 env_specular = half3(0,0,0);
            #endif
            	
                // 最终光照
                float3 finnal_Col = direct_diffuse*2 + direct_specular + env_diffuse + env_specular;
				finnal_Col = ACES_Tonemapping(finnal_Col);
	            finnal_Col = pow(finnal_Col, 1 / 2.2);	// 显示器输出是伽马空间，因此转换回伽马空间
            	
                return float4(finnal_Col, 1);
            }
            ENDCG
        }
    }
	Fallback "Diffuse"
}
