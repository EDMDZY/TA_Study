using System.Runtime.InteropServices;
using UnityEngine;
using Random = UnityEngine.Random;

public class PosUpdate_Basic : MonoBehaviour
{
    public ComputeShader computeShader;
    public GameObject cubePrefab;
    public float speed = 2f;
    public int count = 1000;
    
    private ComputeBuffer posBuffer;
    private ParticleData[] particleData;
    private GameObject[] objects;
    private int kernel;
    private int threadGroups;
    
    [StructLayout(LayoutKind.Sequential)]
    struct ParticleData
    {
        public float x, y, z;
        public ParticleData(Vector3 v) { x = v.x; y = v.y; z = v.z; }
    }
    
    void Start()
    {
        // 初始化粒子数据
        particleData = new ParticleData[count];
        objects = new GameObject[count];
        
        for (int i = 0; i < count; i++)
        {
            Vector3 pos = new Vector3(
                Random.Range(-8f, 8f),
                Random.Range(-3f, 3f),
                Random.Range(-8f, 8f)
            );
            particleData[i] = new ParticleData(pos);
            objects[i] = Instantiate(cubePrefab, pos, Quaternion.identity);
        }
        
        // 创建GPU缓冲区
        int stride = sizeof(float) * 3;
        posBuffer = new ComputeBuffer(count, stride);
        posBuffer.SetData(particleData);
        
        // 设置ComputeShader
        kernel = computeShader.FindKernel("CSMain");
        computeShader.SetBuffer(kernel, "_ParticlePositions", posBuffer);
        computeShader.SetInt("_Count", count);
        
        threadGroups = Mathf.CeilToInt(count / 256f);
    }
    
    void Update()
    {
        // 设置每帧参数
        computeShader.SetFloat("_DeltaTime", Time.deltaTime);
        computeShader.SetFloat("_Speed", speed);
        computeShader.SetFloat("_Time", Time.time);
        
        // 执行GPU计算
        computeShader.Dispatch(kernel, threadGroups, 1, 1);
        
        // ⚠️ 性能瓶颈：强制同步，回读数据
        posBuffer.GetData(particleData);
        
        // 更新GameObject位置
        for (int i = 0; i < count; i++)
        {
            objects[i].transform.position = new Vector3(
                particleData[i].x,
                particleData[i].y,
                particleData[i].z
            );
        }
    }
    
    void OnDestroy()
    {
        posBuffer?.Release();
    }
}