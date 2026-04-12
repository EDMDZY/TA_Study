using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public partial class EasyImageEffect : MonoBehaviour
{
    public Material material;
    // Start is called before the first frame update
    void Start()
    {
        // 判断材质是否是空，材质的shader是否为空，材质shader是否支持当前平台，否则就禁用该脚本防止报错
        if (material == null || material.shader == null ||
            material.shader.isSupported == false)
        {
            enabled = false;
            return;
        }
    }


    /// <summary>
    /// unity后处理方法
    /// </summary>
    /// <param name="source">帧缓冲区传入的图像</param>
    /// <param name="destination">输出的图像</param>
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        //该方法含义：传入的source通过material上的shader的第1个pass处理后输出到destination结果
        Graphics.Blit(source, destination, material, 0);
    }
}
