Shader "Hidden/CustomBloom"
{
    CGINCLUDE
    #include "UnityCG.cginc"

    // ===== Shader属性声明 =====
    sampler2D _MainTex;              // 主纹理（当前处理的输入纹理）
    float4 _MainTex_TexelSize;       // 纹素大小（1/width, 1/height, width, height）
                                     // 用于计算UV偏移量
    float _Offset;                   // Kawase偏移量（C#每帧动态设置）
    float _Threshold;                // 亮度阈值（只保留高于此值的像素）
    sampler2D _BloomTex;             // 模糊纹理（升采样时融合的细节层）
    float _Intensity;                // 泛光强度（合并时的亮度倍数）

    // ===== 顶点着色器输出结构定义 =====
    
    // 降采样输出结构
    struct v2f_DownSample
    {
        float4 pos: SV_POSITION;     // 裁剪空间位置（必须）
        float2 uv: TEXCOORD1;        // 中心采样点UV坐标
        float4 uv01: TEXCOORD2;      // 打包两个对角UV（右上、左下）
        float4 uv23: TEXCOORD3;      // 打包两个对角UV（左上、右下）
        // 总共5个采样点：中心+4个对角
    };
    
    // 升采样输出结构
    struct v2f_UpSample
    {
        float4 pos: SV_POSITION;     // 裁剪空间位置
        float4 uv01: TEXCOORD1;      // 打包2个采样UV（左、左上）
        float4 uv23: TEXCOORD2;      // 打包2个采样UV（上、右上）
        float4 uv45: TEXCOORD3;      // 打包2个采样UV（右、右下）
        float4 uv67: TEXCOORD4;      // 打包2个采样UV（下、左下）
        // 总共8个采样点：形成菱形分布
    };

    // ===== Pass 0: 阈值提取 =====
    // 功能：只保留亮度超过阈值的像素，其余变为黑色
    half4 frag_PreFilter(v2f_img i) : SV_Target
    {
        half4 color = tex2D(_MainTex, i.uv);            // 采样原始颜色

        // 提取最大颜色分量（判断像素亮度）
        // HDR下可能>1，所以能保留高亮区域
        float br = max(max(color.r, color.g), color.b);
        
        // 软阈值公式：(br - _Threshold) / br
        // 举例：
        //   br=2.0, Threshold=1.0 → (2-1)/2 = 0.5（保留50%亮度）
        //   br=1.2, Threshold=1.0 → (1.2-1)/1.2 ≈ 0.167（保留16.7%亮度）
        //   br=0.8, Threshold=1.0 → max(0, 0.8-1)/0.8 = 0（完全过滤）
        // 实现了平滑过渡，避免硬边缘产生的锯齿
        br = max(0.0f, (br - _Threshold)) / max(br, 0.00001f);
        
        color.rgb *= br;  // 应用到RGB各通道，保持颜色色调
        return color;
    }
  
    // ===== Pass 1: Kawase降采样（顶点着色器）=====
    // 功能：计算4个对角方向的采样UV + 中心UV
    // 权重：中心×4 + 四角各×1 = 总权重8（除以8归一化）
    v2f_DownSample Vert_DownSample(appdata_img v)
    {
        v2f_DownSample o;
        o.pos = UnityObjectToClipPos(v.vertex);  // 顶点变换
        
        float2 uv = v.texcoord;                   // 当前像素UV（0-1范围）
        o.uv = uv;                                // 保存中心UV

        // 计算偏移用的纹理像素大小（注意乘以0.5是因为降采样后分辨率减半）
        float4 texelSize = 0.5 * _MainTex_TexelSize;
        
        // 偏移系数：1.0 + _Offset（_Offset从C#传入，逐级增大）
        // _Offset=0时采样相邻像素，_Offset=3时采样更远像素（扩大模糊范围）
        float2 offset = float2(1.0 + _Offset, 1.0 + _Offset);
        
        // 计算四个对角方向的采样UV（相对于中心点的偏移）
        // uv01.xy: 左上方向（-x, -y）
        o.uv01.xy = uv - texelSize * offset;
        // uv01.zw: 右下方向（+x, +y）
        o.uv01.zw = uv + texelSize * offset;
        
        // uv23.xy: 右上方向（-x, +y）注意Y轴方向
        o.uv23.xy = uv - float2(texelSize.x, -texelSize.y) * offset;
        // uv23.zw: 左下方向（+x, -y）
        o.uv23.zw = uv + float2(texelSize.x, -texelSize.y) * offset;
        
        return o;
    }
    
    // ===== Pass 1: Kawase降采样（片段着色器）=====
    // 功能：5点加权平均（中心权重4，四角权重1）
    // 优势：只用5个采样点就实现了可调节范围的模糊效果
    half4 frag_DownsampleKawase(v2f_DownSample i): SV_Target
    {
        half4 sum = tex2D(_MainTex, i.uv) * 4;       // 中心点权重×4（占50%）
        sum += tex2D(_MainTex, i.uv01.xy);           // 左上角权重×1
        sum += tex2D(_MainTex, i.uv01.zw);           // 右下角权重×1
        sum += tex2D(_MainTex, i.uv23.xy);           // 右上角权重×1
        sum += tex2D(_MainTex, i.uv23.zw);           // 左下角权重×1
        
        return sum * 0.125;  // 除以8归一化（保持亮度不变）
    }
    
    // ===== Pass 2: Kawase升采样（顶点着色器）=====
    // 功能：计算8个方向的采样UV（菱形/八角形分布）
    // 权重分配：轴向（上下左右）权重1，对角方向权重2
    // 总权重：1×4 + 2×4 = 12（除以12归一化）
    v2f_UpSample Vert_UpSample(appdata_img v)
    {
        v2f_UpSample o;
        o.pos = UnityObjectToClipPos(v.vertex);
    
        float2 uv = v.texcoord;
        
        // 同样乘以0.5（升采样时需要对应降采样的像素范围）
        float4 texelSize = 0.5 * _MainTex_TexelSize;

        // 偏移系数（与降采样保持一致）
        float2 offset = float2(1.0 + _Offset, 1.0 + _Offset);
        
        // 8个采样方向说明（形成以中心为原点的菱形分布）：
        // ×: 权重大(2)  ○: 权重小(1)
        //        ×
        //     ○  ×  ○
        //  ○  ×  ·  ×  ○
        //     ○  ×  ○
        //        ×
        
        // 方向1: 正左（-2x, 0）权重1
        o.uv01.xy = uv + float2(-texelSize.x * 2, 0) * offset;
        // 方向2: 左上（-x, +y）权重2
        o.uv01.zw = uv + float2(-texelSize.x, texelSize.y) * offset;
        
        // 方向3: 正上（0, +2y）权重1
        o.uv23.xy = uv + float2(0, texelSize.y * 2) * offset;
        // 方向4: 右上（+x, +y）权重2
        o.uv23.zw = uv + texelSize * offset;
        
        // 方向5: 正右（+2x, 0）权重1
        o.uv45.xy = uv + float2(texelSize.x * 2, 0) * offset;
        // 方向6: 右下（+x, -y）权重2
        o.uv45.zw = uv + float2(texelSize.x, -texelSize.y) * offset;
        
        // 方向7: 正下（0, -2y）权重1
        o.uv67.xy = uv + float2(0, -texelSize.y * 2) * offset;
        // 方向8: 左下（-x, -y）权重2
        o.uv67.zw = uv - texelSize * offset;
        
        return o;
    }
    
    // ===== Pass 2: Kawase升采样（片段着色器）=====
    // 功能：8点加权平均 + 叠加_BloomTex的细节
    // 恢复分辨率的同时保留模糊效果
    half4 frag_UpsampleKawase(v2f_UpSample i): SV_Target
    {
        half4 sum = 0;
        
        // 轴向采样点（上下左右）：权重1
        // 这些点距离中心较远，对模糊贡献小
        sum += tex2D(_MainTex, i.uv01.xy);   // 左
        sum += tex2D(_MainTex, i.uv23.xy);   // 上
        sum += tex2D(_MainTex, i.uv45.xy);   // 右
        sum += tex2D(_MainTex, i.uv67.xy);   // 下
        
        // 对角采样点（四角）：权重2
        // 这些点距离中心适中，对模糊贡献大（保持菱形模糊特性）
        sum += tex2D(_MainTex, i.uv01.zw) * 2;  // 左上
        sum += tex2D(_MainTex, i.uv23.zw) * 2;  // 右上
        sum += tex2D(_MainTex, i.uv45.zw) * 2;  // 右下
        sum += tex2D(_MainTex, i.uv67.zw) * 2;  // 左下
        
        return sum * 0.0833;  // 1/12 ≈ 0.0833，归一化权重
    }

    // ===== Pass 3: 合成 =====
    // 功能：将模糊后的光晕叠加回原始画面
    half4 frag_Combine(v2f_img i) : SV_Target
    {
        // 采样原始画面（未经处理的）
        half4 base_color = tex2D(_MainTex, i.uv);
        
        // 采样模糊后的光晕（经过整个Kawase处理链的结果）
        half4 bloom_color = tex2D(_BloomTex, i.uv);
        
        // 叠加公式：原始颜色 + 光晕颜色 × 强度
        // _Intensity控制光晕的亮度倍数
        half3 final_color = base_color.rgb + bloom_color.rgb * _Intensity;
        
        return half4(final_color, 1.0);  // Alpha保持1.0
    }

    ENDCG

    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BlurOffset("BlurOffset",Float) = 1 
    }
    
    SubShader
    {
        // 通用设置：关闭背面剔除、深度写入和深度测试
        Cull Off ZWrite Off ZTest Always
        
        // Pass 0: 阈值提取（提取画面亮部）
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img          // Unity内置的vert_img顶点着色器
            #pragma fragment frag_PreFilter  // 自定义的阈值片段着色器
            ENDCG
        }
        
        // Pass 1: Kawase降采样模糊（缩小分辨率+模糊）
        Pass
        {
            CGPROGRAM
            #pragma vertex Vert_DownSample    // 自定义降采样顶点着色器
            #pragma fragment frag_DownsampleKawase  // 降采样片段着色器
            ENDCG
        }
        
        // Pass 2: Kawase升采样模糊（恢复分辨率+叠加细节）
        Pass
        {
            CGPROGRAM
            #pragma vertex Vert_UpSample      // 自定义升采样顶点着色器
            #pragma fragment frag_UpsampleKawase  // 升采样片段着色器
            ENDCG
        }
        
        // Pass 3: 最终合成（原图+光晕）
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img          // 内置顶点着色器
            #pragma fragment frag_Combine    // 合成片段着色器
            ENDCG
        }
    }
}