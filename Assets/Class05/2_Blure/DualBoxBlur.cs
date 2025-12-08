// 多重模糊（“多重”可在均值模糊或者高斯模糊上叠加）
// 多用于游戏光阴模糊，双重2*2均值模糊
using UnityEngine;

[ExecuteInEditMode]
public class DualBoxBlur : MonoBehaviour
{
    public Material material;
    [Range(0, 10)]
    public int blurIteration = 4;
    [Range(0, 15)]
    public float blurRadius = 5;
    
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
        // 降低模糊的分辨率可以优化性能（降采样）
        int height = source.height / 2;
        int width = source.width / 2;
        // 创建临时画布 来叠加模糊
        RenderTexture RT1 = RenderTexture.GetTemporary(width, height);
        RenderTexture RT2 = RenderTexture.GetTemporary(width, height);
        
        Graphics.Blit(source, RT1);    //先画到RT1上
        material.SetVector("_BlurOffset", new Vector4(blurRadius / width, blurRadius / height, 0, 0));
        
        // 降采样  通过for循环将模糊不断的在两张临时画布上倒来倒去，实现模糊叠加
        for (int i = 0; i < blurIteration; i++)
        {
            RenderTexture.ReleaseTemporary(RT2);
            height /= 2;
            width /= 2;
            RT2 = RenderTexture.GetTemporary(width, height);
            Graphics.Blit(RT1, RT2, material, 0);
            
            RenderTexture.ReleaseTemporary(RT1);
            height /= 2;
            width /= 2;
            RT1 = RenderTexture.GetTemporary(width, height);
            Graphics.Blit(RT2, RT1, material, 0);
        }
        // 升采样
        for (int i = 0; i < blurIteration; i++)
        {
            RenderTexture.ReleaseTemporary(RT2);
            height *= 2;
            width  *= 2;
            RT2 = RenderTexture.GetTemporary(width, height);
            Graphics.Blit(RT1, RT2, material, 0);
            
            RenderTexture.ReleaseTemporary(RT1);
            height *= 2;
            width  *= 2;
            RT1 = RenderTexture.GetTemporary(width, height);
            Graphics.Blit(RT2, RT1, material, 0);
        }
        // 最后输出回destination
        Graphics.Blit(RT1, destination);
        
        //Release 用完后及时释放掉
        RenderTexture.ReleaseTemporary(RT1);
        RenderTexture.ReleaseTemporary(RT2);
    }
}
