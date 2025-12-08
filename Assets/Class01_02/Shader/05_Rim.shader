// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/05_Rim"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "" {}
		_MainColor("Main Color",Color) = (1,1,1,1)
		_Emiss("Emiss", Range(0, 10)) = 1.0
		_RimPower("PimPower", Range(0, 10)) = 1.0
		_Speed("Speed", Vector) = (.34, .85, .92, 1)
	}
	SubShader
	{
		Name "预先写入深度"
		Tags
		{
			"Queue" = "Transparent"
		}
		Pass
		{
			Cull Off
			ZWrite On
			ColorMask 0
			CGPROGRAM
			float4 _Color;
			#pragma vertex vert
			#pragma fragment frag

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
			Name "本体渲染"
			ZWrite Off
			//Blend SrcAlpha OneMinusSrcAlpha 
			Blend One OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION; //模型空间顶点坐标
				float3 normal :NORMAL;
				float2 uv0 : TEXCOORD0; //第一套UV
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv :TEXCOORD0;
				float3 normal_WS :TEXCOORD1;
				float3 viewWS : TEXCOORD2;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainColor;
			float _Emiss;
			float _RimPower;

			v2f vert(appdata v)
			{
				v2f o;
				float3 pos_world = mul(unity_ObjectToWorld, v.vertex);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.normal_WS = UnityObjectToWorldNormal(v.normal);
				o.viewWS = normalize(_WorldSpaceCameraPos - pos_world);
				o.uv = TRANSFORM_TEX(v.uv0, _MainTex);
				return o;
			}

			half4 frag(v2f i) : SV_Target
			{
				half3 normalWS = normalize(i.normal_WS);
				half3 viewWS = normalize(i.viewWS);
				half3 NdotV = saturate(dot(normalWS, viewWS));
				half Fresnel = pow(1 - NdotV, _RimPower);
				half3 final_color = _MainColor.xyz * _Emiss * Fresnel;
				return float4(final_color, 0);
			}
			ENDCG
		}
	}
}
