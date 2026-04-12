Shader "Unlit/ScreenImage"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Brightness ("亮度", float) = 1
        _Saturation ("饱和度", float) = 1
        _Contrast ("对比度", float) = 1
        _VignetteIntensity("VignetteIntensity",Range(0.05,3.0)) = 1.5
		_VignetteRoundness("VignetteRoundness",Range(1,6)) = 5 
		_VignetteSmoothness("VignetteSmoothness",Range(0.05,5)) = 5
    	_HueShift("HueShift",Range(0,1)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        
        Cull Off
        ZWrite On
        //ZTest Always
        
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
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Brightness;
            float _Saturation;
            float _Contrast;
            float _VignetteIntensity;
			float _VignetteRoundness;
			float _VignetteSmoothness;
			float _HueShift;

            // ASE节点原码
            float3 HSVToRGB(float3 c)
			{
				float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
				float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
				return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
			}
			// ASE节点原码
			float3 RGBToHSV(float3 c)
			{
				float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
				float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
				float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
				float d = q.x - min(q.w, q.y);
				float e = 1.0e-10;
				return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                ///1. 自己计算  2. 使用内置方法
                //o.screenPos = o.vertex;
                //o.screenPos.y = o.screenPos.y * _ProjectionParams; // _ProjectionParams根据不同接口进行自动转换（比如dx11坐标原点在左上，而屏幕原点是左下）
                o.screenPos = ComputeScreenPos(o.vertex); // 处理跨平台引起的坐标差异性问题，使用该方法则不需要在片元shader里面进行01限制
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                half2 screenUV = i.screenPos.xy / i.screenPos.w + 0.00001; //透视除法-1 1 只能放片元Shader里面计算 +小数防止被除数为0报错
                //screenUV = screenUV * 0.5 + 0.5; // 把范围限制到0-1  若使用ComputeScreenPos处理过则不需要这一步
                
                float4 col = tex2D(_MainTex, screenUV);
                half3 finalcolor = col.rgb;
            	
            	//色相
				float3 hsv = RGBToHSV(finalcolor);
				hsv.r = hsv.r + _HueShift;
				finalcolor = HSVToRGB(hsv);
                // 亮度
                half3 finalCol = col * _Brightness;
                //饱和度
                float lumin = dot(finalCol, float3(0.22, 0.707, 0.071)); //伽马空间求明度的方法
                //float lumin = dot(finalCol, float3(0.0396, 0.458, 0.0061)); //线性空间求明度的方法
                finalCol = lerp(lumin, finalCol, _Saturation);
                //对比度
                float3 midPoint = float3(0.5, 0.5, 0.5);
                //暗角/晕影(抄unity内置算法)
				float2 d = abs(i.uv - half2(0.5,0.5)) * _VignetteIntensity;
				d = pow(saturate(d), _VignetteRoundness);
				float dist = length(d);
				float vfactor = pow(saturate(1.0 - dist * dist), _VignetteSmoothness);

				finalcolor = finalcolor * vfactor;
				return float4(finalcolor,col.a);
            }
            ENDCG
        }
    }
}
