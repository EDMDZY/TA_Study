// 紧密鸟群：增大flockCenteringAmt，减小collisionDist
// 松散鱼群：减小velocityMatchingAmt，增大nearDist
// 避让群体：增大负的collisionAvoidanceAmt
// 跟随群体：增大mouseAtrractionAmt
using UnityEngine;

public class BoidSpawner : MonoBehaviour
{
    static public BoidSpawner S; // 单例模式，方便其他脚本访问
    
    // ========== 基本参数 ==========
    [Header("基本参数")]
    [Tooltip("生成数量")]
    public int numBoids = 100;
    
    [Tooltip("生成数量")]
    public GameObject boidPrefab;
    
    [Tooltip("初始生成范围半径")]
    public float spawnRadius = 100f;
    
    [Tooltip("初始速度大小")]
    public float spawnVelcoty = 10f;
    
    [Tooltip("最小速度限制")]
    public float minVelocity = 0f;
    
    [Tooltip("最大速度限制")]
    public float maxVelocity = 30f;
    
    // ========== 邻居检测参数 ==========
    [Space(5)]
    [Header("邻居检测参数")]
    [Tooltip("邻居检测距离：值越大，邻居检测范围越大，计算量越大")] 
    public float nearDist = 30f;
    
    [Tooltip("碰撞检测距离：值越小，碰撞检测越敏感")] 
    public float collisionDist = 5f;
    
    // ========== 集群行为参数 ==========
    [Space(5)]
    [Header("集群行为参数")]
    [Tooltip("速度匹配强度系数：值越大，Boid之间速度越同步，群体移动越整齐")]
    public float velocityMatchingAmt = 0.01f;
    
    [Tooltip("凝聚向心：值越大，Boid越喜欢聚在一起，群体越密集")]
    public float flockCenteringAmt = 0.15f;
    
    [Tooltip("碰撞避免强度系数，防止Boid之间互相碰撞（负值表示远离，正值表示靠近）")]
    public float collisionAvoidanceAmt = -0.5f;
    
    // ========== 鼠标交互参数 ==========
    [Space(5)]
    [Header("目标点交互参数")]
    [Tooltip("目标吸引力强度（距离远时靠近目标）")]
    public float mouseAtrractionAmt = 0.01f;
    
    [Tooltip("目标排斥力强度（距离近时远离目标）")]
    public float mouseAvoidanceAmt = 0.75f;
    
    [Tooltip("目标排斥距离阈值（小于此距离时开始排斥）")]
    public float mouseAvoiddanceDsit = 15f;
    
    // ========== 运动平滑参数 ==========
    [Space(5)]
    [Header("运动平滑参数")]
    [Tooltip("值越大，速度变化越急促；值越小，运动越平滑）")]
    [Range(0,1)]public float velocityLerpAmt = 0.25f;
    
    // ========== 目标位置 ==========
    [HideInInspector]public Vector3 mousePos;   // 鼠标/目标位置（Boid会跟随或避开）
    public Transform target;                    // 目标Transform（替代鼠标位置）
    
    // ========== Compute Shader相关 ==========
    public ComputeShader boidsComputeShader;    // 用于GPU计算的Compute Shader
    private ComputeBuffer boidsBuffer;          // GPU数据缓冲区
    private Boid[] boidGameObjects;             // 存储所有Boid GameObject的组件引用
    
    // Boid数据在GPU中的结构（必须与Shader中的结构匹配）
    private struct BoidGPUData
    {
        public Vector3 position;                // 位置向量
        public Vector3 velocity;                // 速度向量
    }
    private BoidGPUData[] boidGPUDataArray;     // CPU端Boid数据数组
    
    void Start()
    {
        S = this; // 设置单例引用
        
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
            randPos.y = 0; // 限制在XZ平面
            boidGPUDataArray[i].position = randPos;
            
            Vector3 randVel = Random.onUnitSphere * spawnVelcoty;
            boidGPUDataArray[i].velocity = randVel;
        }
        
        // 3. 创建Compute Buffer
        int stride = 24; // 数据大小：Vector3(3个float × 4字节) × 2 = 24字节
        boidsBuffer = new ComputeBuffer(numBoids, stride);
        boidsBuffer.SetData(boidGPUDataArray); // 将CPU数据复制到GPU
        
        // 4. 禁用Boid脚本的Update逻辑（因为计算在GPU进行）
        foreach (Boid boid in boidGameObjects)
        {
            if (boid != null)
            {
                boid.enabled = false; // 禁用CPU端的计算，只保留Transform更新
            }
        }
    }
    
    void Update()
    {
        // 更新鼠标/目标位置
        mousePos = target.position;
    
        // 调度Compute Shader
        if (boidsComputeShader != null && boidsBuffer != null)
        {
            int kernel = boidsComputeShader.FindKernel("BoidsUpdate"); // 获取计算内核
        
            // ========== 设置Compute Shader参数 ==========
            boidsComputeShader.SetBuffer(kernel, "boidsBuffer", boidsBuffer);
            boidsComputeShader.SetInt("boidCount", numBoids);          // 传递Boid总数
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
        
            // 调度计算：每个线程组64个线程，根据Boid数量计算需要的线程组数
            int threadGroups = Mathf.CeilToInt(numBoids / 64.0f);
            boidsComputeShader.Dispatch(kernel, threadGroups, 1, 1); // 执行GPU计算
        
            // 从GPU获取计算后的数据
            boidsBuffer.GetData(boidGPUDataArray);
        
            // 更新GameObject的位置和旋转
            for (int i = 0; i < numBoids; i++)
            {
                if (boidGameObjects[i] != null)
                {
                    // 更新位置
                    Vector3 newPos = boidGPUDataArray[i].position;
                
                    // 更新速度（保持数据同步）
                    boidGameObjects[i].velocity = boidGPUDataArray[i].velocity;
                
                    // 计算朝向：看向速度方向的前方
                    Vector3 lookAtPos = newPos + boidGPUDataArray[i].velocity * 0.1f;
                    boidGameObjects[i].transform.LookAt(lookAtPos);
                
                    // 应用位置到Transform
                    boidGameObjects[i].transform.position = newPos;
                }
            }
        }
    }
    
    void OnDestroy()
    {
        // 释放Compute Buffer（重要！避免内存泄漏）
        if (boidsBuffer != null)
        {
            boidsBuffer.Release();
            boidsBuffer = null;
        }
    }
}