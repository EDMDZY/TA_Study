Shader "Hidden/BoxBlur" // Hidden可以在列表中隐藏
{
    CGINCLUDE
        #include "UnityCG.cginc"

        sampler2D _MainTex;
        //float4 _MainTex_TexelSize; // 可获得_MainTex的宽高比 x = 1/width；y = 1/height；z = width；w = height
        float4 _BlurOffset;

        // 2*2均值模糊
        float4 frag_BoxFilter_4Tap (v2f_img i) : SV_Target
        {
            half4 d = _BlurOffset.xyxy * half4(-1,-1,1,1);
            half4 s = 0;
            //对像素周围四个点进行采样然后取平均值（0.25）
            s += tex2D(_MainTex, i.uv + d.xy);
            s += tex2D(_MainTex, i.uv + d.zy);
            s += tex2D(_MainTex, i.uv + d.xw);
            s += tex2D(_MainTex, i.uv + d.zw);
            s *= 0.25;
            return s;
        }

        // 3*3均值模糊
        float4 frag_BoxFilter_9Tap (v2f_img i) : SV_Target
        {
            half4 d = _BlurOffset.xyxy * half4(-1,-1,1,1);
            half4 s = 0;
            //对像素周围四个点进行采样然后取平均值（0.25）
            s += tex2D(_MainTex, i.uv);             // 中间像素
            
            s += tex2D(_MainTex, i.uv + d.xy);
            s += tex2D(_MainTex, i.uv + d.zy);
            s += tex2D(_MainTex, i.uv + d.xw);
            s += tex2D(_MainTex, i.uv + d.zw);

            s += tex2D(_MainTex, i.uv + half2(0, d.w));      // 0 1
            s += tex2D(_MainTex, i.uv + half2(d.z, 0));      // 1 0
            s += tex2D(_MainTex, i.uv + half2(0, d.y));      // 0 -1
            s += tex2D(_MainTex, i.uv + half2(d.x, 0));      // -1 0
            s /= 9;
            return s;
        }
    ENDCG
    
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BlurOffset ("模糊偏移", Vector) = (1,1,0,0)
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img //加_img就可以省略掉输入输出和顶点着色器，因为unity已经把这部分写进了该结构体内
            #pragma fragment frag_BoxFilter_4Tap
            ENDCG
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img //加_img就可以省略掉输入输出和顶点着色器，因为unity已经把这部分写进了该结构体内
            #pragma fragment frag_BoxFilter_9Tap
            ENDCG
        }
    }
}
