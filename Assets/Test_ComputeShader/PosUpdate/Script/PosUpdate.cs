using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using UnityEngine;
using Random = UnityEngine.Random;

public class PosUpdate : MonoBehaviour
{
    //1.创建并绑定computeshader
    public ComputeShader computeShader;
    public GameObject cube;
    public float speed = 1;
    public int count = 1000;

    private List<GameObject> s = new();
    
    [StructLayout(LayoutKind.Sequential)]
    struct Data
    {
        public float x;
        public float y;
        public float z;
    }
    
    // Start is called before the first frame update
    void Start()
    {
        //2.准备输入数据
        Data[] input = new Data[count];
        for (int i = 0; i < count; i++)
        {
            GameObject obj = Instantiate(cube);
            s.Add(obj);
            input[i] = new Data { x = Random.Range(-10, 10), y = Random.Range(-10, 10), z = Random.Range(-10, 10) };
            obj.transform.position = new Vector3(input[i].x, input[i].y, input[i].z);
        }
        
        
        //3.创建buffer传入数据（缓冲区容纳元素数量，元素大小）
        ComputeBuffer posBuffer = new ComputeBuffer(count, sizeof(float) * 3);
        ComputeBuffer outputBuffer = new ComputeBuffer(count, sizeof(float) * 3);
        posBuffer.SetData(input);
        
        //4.将buffer绑定到computeshader
        int kernel = computeShader.FindKernel("CSMain");                // 先获取computeshader中的内核函数
        computeShader.SetBuffer(kernel, "_ParticlePositions", posBuffer);
        computeShader.SetBuffer(kernel, "_OutputData", outputBuffer);

        
        //5.启动computeshader(线程总数：总数据量/每个线程的线程数，并向上取整，可以保证申请的线程数不少于数据量)
        computeShader.Dispatch(kernel, Mathf.CeilToInt(count / 64f), 1, 1);
        
        //7.从Buffer获得计算结果
        Data[] output = new Data[count];
        outputBuffer.GetData(output);
        
        // 8.释放缓冲区
        posBuffer.Release();
        outputBuffer.Release();

        for (int i = 0; i < count; i++)
        {
            s[i].transform.position = new Vector3(output[i].x, output[i].y, output[i].z);
        }
    }

    private void Update()
    {
        // 9.继续主进程
        // 手动传递Unity的Time变量
        computeShader.SetFloat("_DeltaTime", Time.deltaTime);
        computeShader.SetFloat("_Speed", speed);
        
        
    }

    // 拓展
    // 1.ComputeBuffer缓冲区中只能存放值类型的数组，当数据结构复杂时要构造出构造体
    // 2.不将结果回读到CPU(C#脚本)，而是通过shader代码直接读取缓冲区数据并渲染
    // 3.将计算需要的常量设置到computeShader中
    // 4.处理二维三维数据时在不同维度上申请线程数量
    
}
