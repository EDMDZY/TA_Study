// Boid.cs（简化版本）
using UnityEngine;

public class Boid : MonoBehaviour
{
    // 只需要存储速度和用于渲染的数据
    public Vector3 velocity;
    
    // 移除所有计算逻辑，只保留必要的引用
    void Awake()
    {
        // 这里只做必要的初始化，计算交给Compute Shader
        velocity = Random.onUnitSphere * 10f;
        
        // 保持原有的父对象设置
        this.transform.parent = GameObject.Find("Boids").transform;
    }
    
    // 移除Update()和LateUpdate()中的所有计算代码
    // 只保留空的Update用于兼容性
    void Update()
    {
        // 空 - 所有计算在BoidSpawner中通过Compute Shader处理
    }
}