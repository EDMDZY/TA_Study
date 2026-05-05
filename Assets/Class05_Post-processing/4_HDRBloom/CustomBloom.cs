using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 自定义泛光（Bloom）后处理效果
/// 原理：提取画面亮部 → Kawase模糊（降采样+升采样） → 叠加回原图
/// </summary>
[ExecuteInEditMode()]  // 编辑器模式下也能实时预览效果
public class CustomBloom : MonoBehaviour
{
    public Material material;                        // 后处理材质（使用CustomBloom.shader）
    
    [Header("模糊质量")]
    [Range(1, 6)] public int _Iteration = 4;        // 迭代次数：控制降/升采样的层数
                                                    // 越大模糊范围越广，但性能消耗越高
    
    [Header("模糊半径")]
    [Range(0, 5)] public float _BloomRadius = 1;    // 模糊半径：控制Kawase偏移量的大小
                                                    // 越大光晕扩散越远，画面越"梦幻"
    
    [Header("强度与阈值")]
    [Range(0, 20)] public float _Intensity = 1;     // 泛光强度：控制叠加时的亮度倍数
                                                    // 越大光晕越亮，过大会过曝
    
    [Range(0, 1)] public float _Threshold = 1;      // 亮度阈值：只有亮度超过此值的像素才会发光
                                                    // 越小发光区域越多，越大只有最亮的部分发光

    void Start()
    {
        // 兼容性检查：确保当前平台支持图像后处理
        if (material == null || SystemInfo.supportsImageEffects == false
                             || material.shader == null || material.shader.isSupported == false)
        {
            enabled = false;  // 不满足条件则禁用此组件
            return;
        }
    }

    /// <summary>
    /// Unity后处理入口函数：每帧渲染完成后自动调用
    /// </summary>
    /// <param name="source">当前渲染完成的画面（HDR格式保留亮度信息）</param>
    /// <param name="destination">最终输出到屏幕的画面</param>
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        // ========== 第一步：创建所有需要的临时渲染纹理 ==========
        // downRT：存储降采样各层结果（从大到小）
        // 索引0：(w/2, h/2)   索引1：(w/4, h/4)   ...
        // 每个都是前一层的半分辨率，减少计算量
        RenderTexture[] downRT = new RenderTexture[_Iteration + 1];  // +1因为包含第一层阈值结果
        
        // upRT：存储升采样各层结果（从小到大恢复）
        // 索引0：(w/2, h/2)   索引1：(w/4, h/4)   ...
        // 与downRT对应层级分辨率相同（最后一层不需要升采样，所以少一个）
        RenderTexture[] upRT = new RenderTexture[_Iteration];

        // 循环创建所有纹理并设置正确的分辨率
        for (int i = 0; i <= _Iteration; i++)
        {
            // 使用位运算快速计算2的幂次方（性能优于Mathf.Pow）
            // 1<<1=2, 1<<2=4, 1<<3=8, 1<<4=16, 1<<5=32, 1<<6=64
            int div = 1 << (i + 1);
            
            // 创建降采样纹理（分辨率逐级减半）
            downRT[i] = RenderTexture.GetTemporary(
                source.width / div, 
                source.height / div, 
                0,                    // 深度缓冲为0（不需要深度信息）
                source.format         // 保持与源相同的格式（HDR）
            );
            
            // 创建升采样纹理（与对应降采样层分辨率相同）
            if (i < _Iteration)
            {
                upRT[i] = RenderTexture.GetTemporary(
                    source.width / div, 
                    source.height / div, 
                    0, 
                    source.format
                );
            }
        }

        // ========== 第二步：设置Shader全局参数 ==========
        // 强度曲线调整：使用指数函数让滑条调节更自然
        // Mathf.Exp：让Intensity在0-20范围内产生更线性的视觉变化
        float intensity = Mathf.Exp(_Intensity / 10.0f * 0.693f) - 1.0f;
        material.SetFloat("_Intensity", intensity);
        material.SetFloat("_Threshold", _Threshold);

        // ========== 第三步：阈值Pass - 提取画面亮部 ==========
        // 使用Pass 0（frag_PreFilter）：只保留亮度超过_Threshold的像素
        // 其他像素变为黑色，避免暗部参与模糊计算
        Graphics.Blit(source, downRT[0], material, 0);

        // ========== 第四步：生成Kawase偏移量序列 ==========
        // Kawase模糊的核心：每次迭代使用递增的采样偏移距离
        // 偏移量线性增长：1*Radius, 2*Radius, 3*Radius, 4*Radius...
        // 这样用很少的采样点就能实现大范围模糊
        float[] kawaseOffsets = new float[_Iteration];
        for (int i = 0; i < _Iteration; i++)
        {
            // 乘以_BloomRadius控制整体模糊扩散范围
            kawaseOffsets[i] = (i + 1) * _BloomRadius;
        }

        // ========== 第五步：降采样（Downsample）- 逐步缩小分辨率并模糊 ==========
        // 每次迭代：分辨率减半 + 应用Kawase模糊（Pass 1）
        // 降采样过程：w/2→w/4→w/8→w/16→w/32...
        for (int i = 0; i < _Iteration; i++)
        {
            // 设置当前层级的偏移量（逐级增大，模糊范围越来越广）
            material.SetFloat("_Offset", kawaseOffsets[i]);
            
            // Blit操作：将上一层的纹理渲染到当前层（同时执行Pass 1的模糊）
            // 因为当前层分辨率更小，自动完成了降采样
            Graphics.Blit(downRT[i], downRT[i + 1], material, 1);
        }

        // ========== 第六步：升采样（Upsample）- 逐步恢复分辨率并叠加细节 ==========
        // 从最小分辨率开始，逐级放大并融合上一级降采样的细节
        for (int i = _Iteration - 1; i >= 0; i--)
        {
            // 设置对应层级的偏移量（使用与降采样相同的偏移序列，反向应用）
            material.SetFloat("_Offset", kawaseOffsets[i]);
            
            if (i == _Iteration - 1)
            {
                // 第一次升采样：从最小分辨率的downRT[_Iteration]开始
                // 融合downRT[_Iteration-1]的细节（通过_BloomTex传递）
                material.SetTexture("_BloomTex", downRT[_Iteration - 1]);
                Graphics.Blit(downRT[_Iteration], upRT[_Iteration - 1], material, 2);
            }
            else
            {
                // 后续升采样：继续放大上一级的升采样结果
                // 融合对应层降采样的细节
                material.SetTexture("_BloomTex", downRT[i]);
                Graphics.Blit(upRT[i + 1], upRT[i], material, 2);
            }
        }

        // ========== 第七步：合并Pass - 将模糊光晕叠加回原图 ==========
        // 使用Pass 3（frag_Combine）：原图 + 模糊后的亮部×强度
        // upRT[0]包含了最终的全分辨率模糊光晕
        material.SetTexture("_BloomTex", upRT[0]);
        Graphics.Blit(source, destination, material, 3);

        // ========== 第八步：释放所有临时纹理（防止内存泄漏）==========
        // RenderTexture.GetTemporary必须配对ReleaseTemporary
        for (int i = 0; i <= _Iteration; i++)
        {
            RenderTexture.ReleaseTemporary(downRT[i]);
            if (i < _Iteration)
            {
                RenderTexture.ReleaseTemporary(upRT[i]);
            }
        }
    }
}