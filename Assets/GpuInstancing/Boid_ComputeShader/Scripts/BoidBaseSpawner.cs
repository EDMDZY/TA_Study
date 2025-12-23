// BoidSpawner.cs
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BoidSpawner : MonoBehaviour
{
    static public BoidSpawner S;
    
    // 原有参数保持不变...
    public int numBoids = 100;
    public GameObject boidPrefab;
    public float spawnRadius = 100f;
    public float spawnVelcoty = 10f;
    public float minVelocity = 0f;
    public float maxVelocity = 30f;
    public float nearDist = 30f;
    public float collisionDist = 5f;
    public float velocityMatchingAmt = 0.01f;
    public float flockCenteringAmt = 0.15f;
    public float collisionAvoidanceAmt = -0.5f;
    public float mouseAtrractionAmt = 0.01f;
    public float mouseAvoidanceAmt = 0.75f;
    public float mouseAvoiddanceDsit = 15f;
    public float velocityLerpAmt = 0.25f;
    
    public Vector3 mousePos;
    public Transform target;
    
    // 新增：Compute Shader相关
    public ComputeShader boidsComputeShader;
    private ComputeBuffer boidsBuffer;
    private Boid[] boidGameObjects; // 存储所有Boid GameObject的组件
    
    // Boid数据在GPU中的结构（必须与Shader中的结构匹配）
    private struct BoidGPUData
    {
        public Vector3 position;
        public Vector3 velocity;
    }
    private BoidGPUData[] boidGPUDataArray;
    
    void Start()
    {
        S = this;
        
        // 1. 创建GameObject
        boidGameObjects = new Boid[numBoids];
        
        for (int i = 0; i < numBoids; i++)
        {
            GameObject go = Instantiate(boidPrefab);
            boidGameObjects[i] = go.GetComponent<Boid>();
            
            // 设置随机颜色（保持你原有的逻辑）
            MaterialPropertyBlock mpb = new MaterialPropertyBlock();
            mpb.SetColor("_Color", new Color(Random.Range(0f, 1f), Random.Range(0f, 1f), Random.Range(0f, 1f), 1.0f));
            MeshRenderer meshRenderer = go.GetComponentInChildren<MeshRenderer>();
            if (meshRenderer != null)
            {
                meshRenderer.SetPropertyBlock(mpb);
            }
        }
        
        // 2. 初始化GPU数据
        boidGPUDataArray = new BoidGPUData[numBoids];
        for (int i = 0; i < numBoids; i++)
        {
            Vector3 randPos = Random.insideUnitSphere * spawnRadius;
            randPos.y = 0;
            boidGPUDataArray[i].position = randPos;
            
            Vector3 randVel = Random.onUnitSphere * spawnVelcoty;
            boidGPUDataArray[i].velocity = randVel;
        }
        
        // 3. 创建Compute Buffer
        int stride = 24; // Vector3(12字节) * 2
        boidsBuffer = new ComputeBuffer(numBoids, stride);
        boidsBuffer.SetData(boidGPUDataArray);
        
        // 4. 禁用Boid脚本的Update逻辑（因为计算在GPU进行）
        foreach (Boid boid in boidGameObjects)
        {
            if (boid != null)
            {
                // 禁用Boid自己的Update计算
                boid.enabled = false;
            }
        }
    }
    
    void Update()
    {
        // 更新鼠标位置
        mousePos = target.position;
    
        // 调度Compute Shader
        if (boidsComputeShader != null && boidsBuffer != null)
        {
            int kernel = boidsComputeShader.FindKernel("BoidsUpdate");
        
            // 设置参数
            boidsComputeShader.SetBuffer(kernel, "boidsBuffer", boidsBuffer);
            boidsComputeShader.SetInt("boidCount", numBoids);  // 新增：传递Boid数量
            boidsComputeShader.SetFloat("nearDist", nearDist);
            boidsComputeShader.SetFloat("collisionDist", collisionDist);
            boidsComputeShader.SetFloat("velocityMatchingAmt", velocityMatchingAmt);
            boidsComputeShader.SetFloat("flockCenteringAmt", flockCenteringAmt);
            boidsComputeShader.SetFloat("collisionAvoidanceAmt", collisionAvoidanceAmt);
            boidsComputeShader.SetFloat("mouseAtrractionAmt", mouseAtrractionAmt);
            boidsComputeShader.SetFloat("mouseAvoidanceAmt", mouseAvoidanceAmt);
            boidsComputeShader.SetFloat("mouseAvoiddanceDsit", mouseAvoiddanceDsit);
            boidsComputeShader.SetFloat("maxVelocity", maxVelocity);
            boidsComputeShader.SetFloat("minVelocity", minVelocity);
            boidsComputeShader.SetFloat("velocityLerpAmt", velocityLerpAmt);
            boidsComputeShader.SetVector("mousePos", mousePos);
        
            // 调度计算
            int threadGroups = Mathf.CeilToInt(numBoids / 64.0f);
            boidsComputeShader.Dispatch(kernel, threadGroups, 1, 1);
        
            // 从GPU获取数据
            boidsBuffer.GetData(boidGPUDataArray);
        
            // 更新GameObject的位置和旋转
            for (int i = 0; i < numBoids; i++)
            {
                if (boidGameObjects[i] != null)
                {
                    // 更新位置
                    Vector3 newPos = boidGPUDataArray[i].position;
                
                    // 更新速度（如果需要）
                    boidGameObjects[i].velocity = boidGPUDataArray[i].velocity;
                
                    // 计算朝向
                    Vector3 lookAtPos = newPos + boidGPUDataArray[i].velocity * 0.1f;
                    boidGameObjects[i].transform.LookAt(lookAtPos);
                
                    // 应用位置
                    boidGameObjects[i].transform.position = newPos;
                }
            }
        }
    }
    
    void OnDestroy()
    {
        // 释放Compute Buffer
        if (boidsBuffer != null)
        {
            boidsBuffer.Release();
            boidsBuffer = null;
        }
    }
}