//高斯模糊采样周围5*5个像素，且每个像素的权重值不同，消耗较大
//改良后为十字采样，先采样横向5个并乘上每个像素的权重值，再纵向5个并乘上每个像素的权重值
Shader "Hidden/GaussianBlur" // Hidden可以在列表中隐藏
{
    CGINCLUDE
        #include "UnityCG.cginc"

        sampler2D _MainTex;
        //float4 _MainTex_TexelSize; // 可获得_MainTex的宽高比 x = 1/width；y = 1/height；z = width；w = height
        float4 _BlurOffset;

        // 横向  uv这些计算可以放到顶点shader当中计算，性能会有所优化
        float4 frag_HorizontalBlur (v2f_img i) : SV_Target
        {
            half2 uv1 = i.uv + _BlurOffset.xyxy * half2(1, 0) * -2.0; 
            half2 uv2 = i.uv + _BlurOffset.xyxy * half2(1, 0) * -1.0; 
            half2 uv3 = i.uv; 
            half2 uv4 = i.uv + _BlurOffset.xyxy * half2(1, 0) * 1.0; 
            half2 uv5 = i.uv + _BlurOffset.xyxy * half2(1, 0) * 2.0; 
            
            half4 s = 0;
            
            s += tex2D(_MainTex, uv1) * 0.05;             
            s += tex2D(_MainTex, uv2) * 0.25;
            s += tex2D(_MainTex, uv3) * 0.40;
            s += tex2D(_MainTex, uv4) * 0.25;
            s += tex2D(_MainTex, uv5) * 0.05;
            
            return s;
        }

        // 纵向
        float4 frag_VerticalBluir (v2f_img i) : SV_Target
        {
            half2 uv1 = i.uv + _BlurOffset.xyxy * half2(0, 1) * -2.0; 
            half2 uv2 = i.uv + _BlurOffset.xyxy * half2(0, 1) * -1.0; 
            half2 uv3 = i.uv; 
            half2 uv4 = i.uv + _BlurOffset.xyxy * half2(0, 1) * 1.0; 
            half2 uv5 = i.uv + _BlurOffset.xyxy * half2(0, 1) * 2.0; 
            
            half4 s = 0;
            
            s += tex2D(_MainTex, uv1) * 0.05;             
            s += tex2D(_MainTex, uv2) * 0.25;
            s += tex2D(_MainTex, uv3) * 0.40;
            s += tex2D(_MainTex, uv4) * 0.25;
            s += tex2D(_MainTex, uv5) * 0.05;

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
            #pragma fragment frag_HorizontalBlur
            ENDCG
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img //加_img就可以省略掉输入输出和顶点着色器，因为unity已经把这部分写进了该结构体内
            #pragma fragment frag_VerticalBluir
            ENDCG
        }
    }
}
