using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ScreenPixelEffect : MonoBehaviour
{
    //1.创建并绑定computeshader
    public ComputeShader computeShader;
    public float _DownSample;
    public float threshold;

    private int kernel;
    private int threadGroupsX;
    private int threadGroupsY;
    
    // Start is called before the first frame update
    void Start()
    {
        if (computeShader == null)
        {
            Debug.LogError("请分配ComputeShader！");
            enabled = false;
            return;
        }
        
        kernel = computeShader.FindKernel("CSMain");
        
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        int width = (int)(source.width / _DownSample);
        int height = (int)(source.height / _DownSample);
        
        // 创建临时RT
        RenderTexture RT = RenderTexture.GetTemporary(width, height);
        RT.enableRandomWrite = true;
        RT.Create();
        Graphics.Blit(source, RT);
        // 设置computeShader参数
        
        computeShader.SetTexture(kernel, "_Source", RT);
        computeShader.SetTexture(kernel, "_Result", RT);

        computeShader.SetFloat("_Width", width);
        computeShader.SetFloat("_Height", height);
        computeShader.SetFloat("_Threshold", threshold);
        
        // 计算所需线程数
        threadGroupsX = Mathf.CeilToInt(width / 16.0f);
        threadGroupsY = Mathf.CeilToInt(height / 16.0f);
        // 执行ComputeShader
        computeShader.Dispatch(kernel, threadGroupsX, threadGroupsY, 1);
        // 将结果输出到屏幕
        Graphics.Blit(RT, destination);
        
        // 释放临时渲染纹理，避免内存泄漏
        RenderTexture.ReleaseTemporary(RT);
        
        // 数据流向
        // 第1步：相机渲染原始图像到source纹理（GPU内）
        //     ↓
        // 第2步：ComputeShader读取source，写入result纹理（GPU内）
        //     ↓
        // 第3步：Graphics.Blit(result, destination) 直接显示到屏幕（GPU内）
        // 全程数据从未离开GPU！
    }

    private void OnDestroy()
    {
        
    }
}
