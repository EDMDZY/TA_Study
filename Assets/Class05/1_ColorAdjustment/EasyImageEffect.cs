using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class EasyImageEffect : MonoBehaviour
{
    public Material material;
    // Start is called before the first frame update
    void Start()
    {
        if (material == null || material.shader == null ||
            material.shader.isSupported == false)
        {
            enabled = false;
            return;
        }
    }


    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, material, 0);
    }
}
