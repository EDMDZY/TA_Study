using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public partial class EasyImageEffect : MonoBehaviour
{
    public Material material;
    public float _Brightness = 1;
    public float _Saturation = 1;
    public float _Contrast = 1;
    [Range(0.05f,3.0f)]
    public float _VignetteIntensity = 1.5f;
    [Range(1.0f, 6.0f)]
    public float _VignetteRoundness = 5.0f;
    [Range(0.05f, 5.0f)]
    public float _VignetteSmoothness = 5.0f;
    [Range(0.0f, 1.0f)]
    public float _HueShift = 0.0f;
    
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
    /// unity特定函数，每次场景中所有渲染完后都会调用一次该函数进行后处理操作
    /// 该方法只有放在摄像机上才生效
    /// </summary>
    /// <param name="source">帧缓冲区传入的图像</param>
    /// <param name="destination">输出的图像</param>
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        material.SetFloat("_Brightness", _Brightness);
        material.SetFloat("_Saturation", _Saturation);
        material.SetFloat("_Contrast", _Contrast);
        material.SetFloat("_VignetteIntensity", _VignetteIntensity);
        material.SetFloat("_VignetteRoundness", _VignetteRoundness);
        material.SetFloat("_VignetteSmoothness", _VignetteSmoothness);
        material.SetFloat("_HueShift", _HueShift);
        //该方法含义：传入的source通过material上的shader的第1个pass处理后输出到destination结果
        Graphics.Blit(source, destination, material, 0);
    }
}
