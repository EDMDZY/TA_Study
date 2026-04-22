using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ComputeShaderDemo : MonoBehaviour
{
    //1.创建并绑定computeshader
    public ComputeShader computeShader;
    public int count;
    
    // Start is called before the first frame update
    void Start()
    {
        Debug.Log("数据量" + count);
        
        //2.准备输入数据
        int[] input = new int[count];
        for (int i = 0; i < count; i++)
        {
            input[i] = i;
        }
        
        //3.创建buffer传入数据（缓冲区容纳元素数量，元素大小）
        ComputeBuffer inputBuffer = new ComputeBuffer(count, sizeof(int));
        ComputeBuffer outputBuffer = new ComputeBuffer(count, sizeof(int));
        inputBuffer.SetData(input);
        
        //4.将buffer绑定到computeshader
        int kernel = computeShader.FindKernel("CSMain");                // 先获取computeshader中的内核函数
        computeShader.SetBuffer(kernel, "_InputData", inputBuffer);
        computeShader.SetBuffer(kernel, "_OutputData", outputBuffer);
        
        //5.启动computeshader(线程总数：总数据量/每个线程的线程数，并向上取整，可以保证申请的线程数不少于数据量)
        computeShader.Dispatch(kernel, Mathf.CeilToInt(count / 64f), 1, 1);
        
        //7.从Buffer获得计算结果
        int[] output = new int[count];
        outputBuffer.GetData(output);
        
        // 8.释放缓冲区
        inputBuffer.Release();
        outputBuffer.Release();
        
        // 9.继续主进程
        Debug.Log("打印前十个");
        for (int i = 0; i < 10; i++)
        {
            Debug.Log($"前10个值：{output[i]}");
        }
        
        Debug.Log("打印最后十个");
        for (int i = count - 10; i < count; i++)
        {
            Debug.Log($"后10个值：{output[i]}");
        }
    }

    // 拓展
    // 1.ComputeBuffer缓冲区中只能存放值类型的数组，当数据结构复杂时要构造出构造体
    // 2.不将结果回读到CPU(C#脚本)，而是通过shader代码直接读取缓冲区数据并渲染
    // 3.将计算需要的常量设置到computeShader中
    // 4.处理二维三维数据时在不同维度上申请线程数量
    
}
