Shader "Unlit/03_Clip"
{
    Properties
    {
        _MainCol ("颜色", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _NoiseTex ("噪声纹理", 2D) = "white" {}
        [Enum(UnityEngine.Rendering.CullMode)]_CullMode("CullMode", float) = 2
        _ClipNum("裁剪阈值", Range(-0.1,1.1)) = 0.0
        _Speed("速度", Vector) = (0,0,0,0)
    }
    SubShader
    {
        Cull [_CullMode]
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
                float4 pos : SV_POSITION;
                float2 uv0 :TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;

            
            float _ClipNum;
            float4 _Speed;
            float4 _MainCol;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv0 = TRANSFORM_TEX(v.uv, _MainTex);
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //注：一定用单通道
                float final = tex2D(_MainTex, i.uv0 + _Time.y * _Speed.xy).r;
                float noise = tex2D(_NoiseTex, i.uv0 + _Time.y * _Speed.zw).r;
                // clip會將小于0的部分丢掉
                clip(final - noise - _ClipNum);
                //return  float4(i.uv0, 0, 0);
                return  _MainCol;
            }
            ENDCG
        }
    }
}
