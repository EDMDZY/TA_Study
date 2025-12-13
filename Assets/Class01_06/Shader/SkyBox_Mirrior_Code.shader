Shader "Custom/SkyBox_Mirrior_Code"
{
    Properties
    {
        _MainTex ("Cubemap", Cube) = "white" {}
        _RotationSpeed ("Rotation Speed", Float) = 1.0
        _Expose ("_Expose", Float) = 1.0
        [IntRange]_Index ("视窗模板编号", Range(0,255)) = 1
    }
    
    SubShader
    {
        Tags { "Queue"="AlphaTest+15" }
        ZTest Always
       
        Pass
        {

            Stencil
            {
                Ref [_Index]
                Comp Equal
            }
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            
            samplerCUBE _MainTex;
            float _RotationSpeed;
            float _Expose;
            
            struct appdata
            {
                float4 vertex : POSITION;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 uv : TEXCOORD0;
            };
            
            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                
                // 计算旋转
                float angle = _Time.y * _RotationSpeed;
                float sinAngle, cosAngle;
                sincos(angle, sinAngle, cosAngle);
                float2x2 rotationMatrix = float2x2(cosAngle, -sinAngle, sinAngle, cosAngle);
                
                // 应用旋转
                o.uv = v.vertex.xyz;
                o.uv.xz = mul(rotationMatrix, o.uv.xz);
                
                return o;
            }
            
            fixed4 frag(v2f i) : SV_Target
            {
                return texCUBE(_MainTex, i.uv) * _Expose;
            }
            ENDCG
        }
    }
}