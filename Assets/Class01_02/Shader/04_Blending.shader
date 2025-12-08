Shader "Unlit/04_Blending"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "" {}
		_MainColor("Main Color",Color) = (1,1,1,1)
		_Emiss("Emiss", Float) = 1.0
		_Speed("Speed", Vector) = (.34, .85, .92, 1)
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" }
        
        Pass
        {
            ZWrite Off
            Cull Back
			Blend SrcAlpha One
			//Blend One OneMinusSrcAlpha
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION; //模型空间顶点坐标
				half2 texcoord0 : TEXCOORD0; //第一套UV
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 uv :TEXCOORD0;
            	float3 pos_local : TEXCOORD1;
            };

            sampler2D _MainTex;
			float4 _MainTex_ST;
			float _Cutout;
			float4 _Speed;
			sampler2D _NoiseMap;
			float4 _NoiseMap_ST;
			float4 _MainColor;
			float _Emiss;

            v2f vert (appdata v)
            {
                v2f o;
				float4 pos_world = mul(unity_ObjectToWorld, v.vertex);
				float4 pos_view = mul(UNITY_MATRIX_V, pos_world);
				float4 pos_clip = mul(UNITY_MATRIX_P, pos_view);
				o.pos = pos_clip;
				//o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = v.texcoord0 * _MainTex_ST.xy + _MainTex_ST.zw;
				o.uv.zw = v.texcoord0 * _NoiseMap_ST.xy + _NoiseMap_ST.zw;
				//o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.pos_local = v.vertex.xyz;
				return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
            	half3 col = _MainColor.xyz;
            	half alpha = tex2D(_MainTex, i.uv+ _Time.y * 0.1 * _Speed.xy).r * _MainColor.a;
            	return float4(col, alpha);
            }
            ENDCG
        }
    }
}
