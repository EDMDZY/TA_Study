using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using UnityEngine;
using Random = UnityEngine.Random;

public class PosUpdateAllG : MonoBehaviour
{
    public ComputeShader computeShader;
    public Mesh cubeMesh;
    public Material instancedMaterial; // 必须勾选 Enable GPU Instancing
    public float speed = 2f;
    public int count = 100000; // 可以处理10万+物体

    private ComputeBuffer posBuffer;
    private ComputeBuffer argsBuffer;
    private uint[] args = new uint[5];
    private int kernel;
    private int threadGroups;
    private Bounds bounds;

    [StructLayout(LayoutKind.Sequential)]
    struct ParticleData
    {
        public float x, y, z;

        public ParticleData(Vector3 v)
        {
            x = v.x;
            y = v.y;
            z = v.z;
        }
    }

    void Start()
    {
        // 初始化随机位置
        ParticleData[] initialData = new ParticleData[count];
        for (int i = 0; i < count; i++)
        {
            initialData[i] = new ParticleData(new Vector3(
                Random.Range(-15f, 15f),
                Random.Range(-5f, 5f),
                Random.Range(-15f, 15f)
            ));
        }

        // 创建位置缓冲区
        int stride = sizeof(float) * 3;
        posBuffer = new ComputeBuffer(count, stride);
        posBuffer.SetData(initialData);

        // 设置ComputeShader
        kernel = computeShader.FindKernel("CSMain");
        computeShader.SetBuffer(kernel, "_ParticlePositions", posBuffer);
        computeShader.SetInt("_Count", count);
        threadGroups = Mathf.CeilToInt(count / 256f); // 向上取整

        // argsBuffer 内容（GPU内存）：
        //     ┌─────────────────────────────────┐
        //     │ [0] 索引数量: 36                │ ← 每个实例用36个索引
        //     │ [1] 实例数量: 50000             │ ← 总共50000个实例
        //     │ [2] 起始索引: 0                 │ ← 从索引0开始
        //     │ [3] 起始顶点: 0                 │ ← 从顶点0开始
        //     │ [4] 实例偏移: 0                 │ ← 保留
        //     └─────────────────────────────────┘
        //     ↓
        // GPU读取这个命令
        //     ↓
        // "知道了，我要用索引0-35，
        // 重复绘制50000次，
        // 每次用不同的位置（从_ParticlePositions读取）"
        //     ↓
        // Graphics.DrawMeshInstancedIndirect()
        //     ↓
        // 一次DrawCall完成50000个立方体渲染！
        //  设置GPU Instancing参数,告诉GPU "如何绘制这些物体" 的命令缓冲区，相当于一个绘制指令清单
        args[0] = cubeMesh.GetIndexCount(0);  // 每个物体需要绘制多少个三角形索引
        args[1] = (uint)count;                        // 要绘制多少个物体（实例数量）
        args[2] = cubeMesh.GetIndexStart(0);  // 从索引缓冲区的哪个位置开始读
        args[3] = cubeMesh.GetBaseVertex(0);  // 从顶点缓冲区的哪个位置开始读
        args[4] = 0;                                  // 每个实例的起始索引（保留参数，通常为0）

        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        argsBuffer.SetData(args);

        // 绑定位置缓冲区到材质
        instancedMaterial.SetBuffer("_ParticlePositions", posBuffer);

        // 设置渲染边界
        bounds = new Bounds(Vector3.zero, new Vector3(50, 20, 50));
    }

    void Update()
    {
        // 执行ComputeShader更新位置
        computeShader.SetFloat("_Speed", speed);
        computeShader.Dispatch(kernel, threadGroups, 1, 1);

        // 直接GPU渲染，不回读CPU！
        Graphics.DrawMeshInstancedIndirect(cubeMesh, 0, instancedMaterial, bounds, argsBuffer);
        // 你的代码调用
        //     ↓
        // Graphics.DrawMeshInstancedIndirect
        //     ↓
        // CPU告诉GPU: "这里有argsBuffer，你按这个画"
        //     ↓ (CPU工作结束，继续下一行代码)
        // GPU开始工作:
        // 1. 读取 argsBuffer → "要画50000个立方体"
        // 2. 读取 cubeMesh → "每个立方体长这样"
        // 3. 读取 instancedMaterial → "用这个着色器"
        // 4. 执行顶点着色器，每个实例调用一次setup()
        // 5. setup() 从 _ParticlePositions[instanceID] 读取位置
        // 6. 渲染50000个立方体
        //     ↓
        // GPU继续处理下一帧
    }

    void OnDestroy()
    {
        posBuffer?.Release();
        argsBuffer?.Release();
    }

    // 拓展
    // 1.ComputeBuffer缓冲区中只能存放值类型的数组，当数据结构复杂时要构造出构造体
    // 2.不将结果回读到CPU(C#脚本)，而是通过shader代码直接读取缓冲区数据并渲染
    // 3.将计算需要的常量设置到computeShader中
    // 4.处理二维三维数据时在不同维度上申请线程数量
}