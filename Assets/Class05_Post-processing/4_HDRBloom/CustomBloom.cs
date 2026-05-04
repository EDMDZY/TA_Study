using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode()]
public class CustomBloom : MonoBehaviour
{
    public Material material;
    [Range(1, 6)] public int _Iteration = 4;
    [Range(0, 5)] public float _BloomRadius = 1;
    [Range(0, 20)] public float _Intensity = 1;
    [Range(0, 1)] public float _Threshold = 1;

    void Start()
    {
        if (material == null || SystemInfo.supportsImageEffects == false
                             || material.shader == null || material.shader.isSupported == false)
        {
            enabled = false;
            return;
        }
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        // === 创建临时渲染纹理 ===
        RenderTexture[] downRT = new RenderTexture[_Iteration + 1];
        RenderTexture[] upRT = new RenderTexture[_Iteration];

        for (int i = 0; i <= _Iteration; i++)
        {
            int div = 1 << (i + 1);
            downRT[i] = RenderTexture.GetTemporary(source.width / div, source.height / div, 0, source.format);
            
            if (i < _Iteration)
            {
                upRT[i] = RenderTexture.GetTemporary(source.width / div, source.height / div, 0, source.format);
            }
        }

        // === 设置材质参数 ===
        float intensity = Mathf.Exp(_Intensity / 10.0f * 0.693f) - 1.0f;
        material.SetFloat("_Intensity", intensity);
        material.SetFloat("_Threshold", _Threshold);

        // === 阈值 ===
        Graphics.Blit(source, downRT[0], material, 0);

        // === 生成Kawase偏移序列 ===
        float[] kawaseOffsets = new float[_Iteration];
        for (int i = 0; i < _Iteration; i++)
        {
            // 线性增长的偏移量，乘以半径系数
            kawaseOffsets[i] = (i + 1) * _BloomRadius;
        }

        // === 降采样 ===
        for (int i = 0; i < _Iteration; i++)
        {
            material.SetFloat("_Offset", kawaseOffsets[i]);
            Graphics.Blit(downRT[i], downRT[i + 1], material, 1);
        }

        // === 升采样 ===
        for (int i = _Iteration - 1; i >= 0; i--)
        {
            material.SetFloat("_Offset", kawaseOffsets[i]);
            
            if (i == _Iteration - 1)
            {
                material.SetTexture("_BloomTex", downRT[_Iteration - 1]);
                Graphics.Blit(downRT[_Iteration], upRT[_Iteration - 1], material, 2);
            }
            else
            {
                material.SetTexture("_BloomTex", downRT[i]);
                Graphics.Blit(upRT[i + 1], upRT[i], material, 2);
            }
        }

        // === 合并 ===
        material.SetTexture("_BloomTex", upRT[0]);
        Graphics.Blit(source, destination, material, 3);

        // === 释放临时纹理 ===
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