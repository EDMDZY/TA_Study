Shader "Unlit/ScreenImage"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

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
                fixed4 col = tex2D(_MainTex, screenUV);
                return col;
            }
            ENDCG
        }
    }
}
