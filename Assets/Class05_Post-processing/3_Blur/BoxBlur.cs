using System.Collections;
using System.Collections.Generic;
using UnityEngine;

// 在编辑器模式下也允许脚本运行（无需进入播放模式）
[ExecuteInEditMode()]
public class BoxBlur : MonoBehaviour 
{
    public Material material;           // 用于模糊效果的材质（包含BoxBlur Shader）
    
    [Range(0, 10)]
    public int _Iteration = 4;          // 模糊迭代次数，次数越多模糊效果越强
    
    [Range(0, 15)]
    public float _BlurRadius = 5.0f;    // 模糊半径，控制采样偏移距离
    
    [Range(1, 10)]
    public float _DownSample = 2.0f;    // 降采样倍数，值越大渲染分辨率越低，性能越好但画质下降

    void Start () 
    {
        // 检查材质、Shader及系统是否支持图像效果
        // 如果不满足条件，则禁用该脚本组件
        if (material == null || SystemInfo.supportsImageEffects == false
            || material.shader == null || material.shader.isSupported == false)
        {
            enabled = false;
            return;
        }
    }

    // OnRenderImage 在相机渲染完成后调用，用于后处理特效
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        // 根据降采样倍数计算临时渲染纹理的宽高
        // 降采样可以减少需要处理的像素数量，提升性能
        int width = (int)(source.width / _DownSample);
        int height = (int)(source.height / _DownSample);
        
        // 获取两块临时渲染纹理用于乒乓操作（Ping-Pong）
        // 两块纹理交替作为输入和输出，避免重复创建新纹理
        RenderTexture RT1 = RenderTexture.GetTemporary(width, height);
        RenderTexture RT2 = RenderTexture.GetTemporary(width, height);

        // 将原始图像复制到RT1作为初始输入
        Graphics.Blit(source, RT1);

        // 设置模糊偏移量
        // x: 水平偏移步长（模糊半径 / 源纹理宽度）
        // y: 垂直偏移步长（模糊半径 / 源纹理高度）
        // 这样偏移量会随着纹理分辨率自动适配
        material.SetVector("_BlurOffset", new Vector4(_BlurRadius / source.width, _BlurRadius / source.height, 0, 0));
        
        // 乒乓操作循环，执行多次模糊迭代
        for (int i = 0; i < _Iteration; i++)
        {
            // 将RT1模糊后输出到RT2
            Graphics.Blit(RT1, RT2, material, 0);  // Pass 0: 4-Tap Box Blur
            // 将RT2模糊后输出回RT1，完成一次完整迭代
            Graphics.Blit(RT2, RT1, material, 0);
        }

        // 将最终结果从RT1输出到目标渲染纹理（通常是屏幕）
        Graphics.Blit(RT1, destination);

        // 释放临时渲染纹理，避免内存泄漏
        RenderTexture.ReleaseTemporary(RT1);
        RenderTexture.ReleaseTemporary(RT2);
    }
}