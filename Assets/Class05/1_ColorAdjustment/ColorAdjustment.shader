Shader "Hidden/ColorAdjustment" // Hidden可以在列表中隐藏
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Brightness ("亮度", float) = 1
        _Saturation ("饱和度", float) = 1
        _Contrast ("对比度", float) = 1
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img //加_img就可以省略掉输入输出和顶点着色器，因为unity已经把这部分写进了该结构体内
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float _Brightness;
            float _Saturation;
            float _Contrast;

            float4 frag (v2f_img i) : SV_Target
            {
                half4 col = tex2D(_MainTex, i.uv);
                // 亮度
                half3 finalCol = col * _Brightness;
                //饱和度
                float lumin = dot(finalCol, float3(0.22, 0.707, 0.071)); //伽马空间求明度的方法
                //float lumin = dot(finalCol, float3(0.0396, 0.458, 0.0061)); //线性空间求明度的方法
                finalCol = lerp(lumin, finalCol, _Saturation);
                //对比度
                float3 midPoint = float3(0.5, 0.5, 0.5);
                finalCol = lerp(midPoint, finalCol, _Contrast);

                return float4(finalCol, col.a);
            }
            ENDCG
        }
    }
}
