Shader "Unlit/Scan_Hand"
{
    Properties
    {
        _LineTex ("扫描线贴图", 2D) = "white" {}
        _PowStr ("菲涅尔强度", Float) = 1
    	_InnerCol ("内部颜色", Color) = (1,1,1,1)
    	_OutCol ("外部颜色", Color) = (1,1,1,1)
    	_RimStr ("边缘光强度", Float) = 1
    	_FlowFillNum ("边缘光密度", Float) = 1
    	_LineStr ("扫描线强度", Float) = 1
    	_FlowSpeed ("扫描线速度", Vector) = (1,1,0,0)
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" }
        Pass
        {
			Cull Off 
			ZWrite On 
			ColorMask 0
			CGPROGRAM
			
			#pragma vertex vert 
			#pragma fragment frag
			
			float4 _Color;
			
			float4 vert(float4 vertexPos : POSITION) : SV_POSITION
			{
				return UnityObjectToClipPos(vertexPos);
			}

			float4 frag(void) : COLOR
			{
				return _Color;
			}
			ENDCG
		}
        Pass
        {
        	ZWrite Off
	        Blend SrcAlpha One
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
                float3 viewDir_WS : TEXCOORD1;
                float3 pos_WS : TEXCOORD2;
                float3 normal_WS : TEXCOORD3;
                float3 flowPoint_WS : TEXCOORD4;
            };

            sampler2D _LineTex;
            float4 _LineTex_ST;
            float _PowStr;
            float _RimStr;
            float _FlowFillNum;
            float4 _InnerCol;
            float4 _OutCol;
            float _LineStr;
            float4 _FlowSpeed;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos_WS = mul(unity_ObjectToWorld, v.vertex);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal_WS = UnityObjectToWorldNormal(v.normal);
                o.viewDir_WS = normalize(_WorldSpaceCameraPos - o.pos_WS);
                o.uv = TRANSFORM_TEX(v.uv, _LineTex);
				o.flowPoint_WS = mul(unity_ObjectToWorld, float4(0,0,0,1));	// 获取一个世界中的点来作为锚点
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float4 Fresnel = pow(1 - dot(i.viewDir_WS, i.normal_WS), _PowStr);
            	float4 ColLerp = lerp(_InnerCol, _OutCol * _RimStr, Fresnel);

            	half2 uv_Flow = (i.pos_WS.xy - i.flowPoint_WS.xy) * _FlowFillNum;	// 通过与自定义的世界锚点进行计算，防止在移动对象时导致扫描线偏移
            	uv_Flow = uv_Flow + _Time.y * _FlowSpeed.xy;
				float4 finUV = tex2D(_LineTex, uv_Flow) * _LineStr;
            	
            	float4 finClo = ColLerp + finUV;
                return finClo;
            }
            ENDCG
        }
    }
}
