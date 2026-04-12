using UnityEngine;

[ExecuteInEditMode]
public class GaussianBlur : MonoBehaviour
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
        // 降低模糊的分辨率可以优化性能
        int height = source.height / 2;
        int width = source.width / 2;
        // 创建临时画布 来叠加模糊
        RenderTexture RT1 = RenderTexture.GetTemporary(width, height);
        RenderTexture RT2 = RenderTexture.GetTemporary(width, height);
        
        Graphics.Blit(source, RT1);    //先画到RT1上
        material.SetVector("_BlurOffset", new Vector4(blurRadius / width, blurRadius / height, 0, 0));
        // 通过for循环将模糊不断的在两张临时画布上倒来倒去，实现模糊叠加
        for (int i = 0; i < blurIteration; i++)
        {
            Graphics.Blit(RT1, RT2, material, 0);
            Graphics.Blit(RT2, RT1, material, 1);
        }
        // 最后输出回destination
        Graphics.Blit(RT1, destination);
        
        //Release 用完后及时释放掉
        RenderTexture.ReleaseTemporary(RT1);
        RenderTexture.ReleaseTemporary(RT2);
    }
}
