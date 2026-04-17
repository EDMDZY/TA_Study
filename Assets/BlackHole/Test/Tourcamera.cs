using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Tourcamera : MonoBehaviour
{
    public Transform tourCamera;
    #region 相机移动参数
    public float moveSpeed = 1.0f;
    public float rotateSpeed = 90.0f;
    public float shiftRate = 2.0f;// 按住Shift加速
    public float minDistance = 0.5f;// 相机离不可穿过的表面的最小距离（小于等于0时可穿透任何表面）
    public bool lockCursor = true; // 是否锁定并隐藏鼠标
    #endregion
    #region 运动速度和其每个方向的速度分量
    private Vector3 direction = Vector3.zero;
    private Vector3 speedForward;
    private Vector3 speedBack;
    private Vector3 speedLeft;
    private Vector3 speedRight;
    private Vector3 speedUp;
    private Vector3 speedDown;
    #endregion
    
    private float mouseX = 0f;
    private float mouseY = 0f;
    private float rotationX = 0f;
    private float rotationY = 0f;
    
    void Start()   
    {
        if (tourCamera == null) tourCamera = gameObject.transform;
        
        // 锁定并隐藏鼠标
        if (lockCursor)
        {
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;
        }
        
        // 初始化旋转角度
        rotationX = tourCamera.eulerAngles.y;
        rotationY = tourCamera.eulerAngles.x;
    }
    
    void Update()
    {
        // 按ESC键释放鼠标
        if (Input.GetKeyDown(KeyCode.Escape))
        {
            lockCursor = !lockCursor;
            if (lockCursor)
            {
                Cursor.lockState = CursorLockMode.Locked;
                Cursor.visible = false;
            }
            else
            {
                Cursor.lockState = CursorLockMode.None;
                Cursor.visible = true;
            }
        }
        
        // 只有在鼠标锁定时才处理相机控制
        if (lockCursor)
        {
            GetDirection();
            GetMouseRotation();
            
            // 检测是否离不可穿透表面过近
            RaycastHit hit;
            while (Physics.Raycast(tourCamera.position, direction, out hit, minDistance))
            {
                // 消去垂直于不可穿透表面的运动速度分量
                float angel = Vector3.Angle(direction, hit.normal);
                float magnitude = Vector3.Magnitude(direction) * Mathf.Cos(Mathf.Deg2Rad * (180 - angel));
                direction += hit.normal * magnitude;
            }
            tourCamera.Translate(direction * moveSpeed * Time.deltaTime, Space.World);
        }
    }
    
    private void GetMouseRotation()
    {
        // 获取鼠标输入
        mouseX = Input.GetAxis("Mouse X") * rotateSpeed * Time.deltaTime;
        mouseY = Input.GetAxis("Mouse Y") * rotateSpeed * Time.deltaTime;
        
        // 更新旋转角度
        rotationX += mouseX;
        rotationY -= mouseY;
        
        // 限制垂直旋转角度，避免相机翻转
        rotationY = Mathf.Clamp(rotationY, -90f, 90f);
        
        // 应用旋转
        tourCamera.rotation = Quaternion.Euler(rotationY, rotationX, 0f);
        
        // 旋转运动速度方向
        direction = V3RotateAround(direction, Vector3.up, mouseX);
        direction = V3RotateAround(direction, tourCamera.right, -mouseY);
    }
    
    private void GetDirection()
    {
        #region 加速移动
        if (Input.GetKeyDown(KeyCode.LeftShift)) moveSpeed *= shiftRate;
        if (Input.GetKeyUp(KeyCode.LeftShift)) moveSpeed /= shiftRate;
        #endregion
        #region 键盘移动
        // 复位
        speedForward = Vector3.zero;
        speedBack = Vector3.zero;
        speedLeft = Vector3.zero;
        speedRight = Vector3.zero;
        speedUp = Vector3.zero;
        speedDown = Vector3.zero;
        
        // 获取按键输入
        if (Input.GetKey(KeyCode.W)) speedForward = tourCamera.forward;
        if (Input.GetKey(KeyCode.S)) speedBack = -tourCamera.forward;
        if (Input.GetKey(KeyCode.A)) speedLeft = -tourCamera.right;
        if (Input.GetKey(KeyCode.D)) speedRight = tourCamera.right;
        if (Input.GetKey(KeyCode.E)) speedUp = Vector3.up;
        if (Input.GetKey(KeyCode.Q)) speedDown = Vector3.down;
        
        direction = speedForward + speedBack + speedLeft + speedRight + speedUp + speedDown;
        #endregion
    }
    
    public Vector3 V3RotateAround(Vector3 source, Vector3 axis, float angle)
    {
        Quaternion q = Quaternion.AngleAxis(angle, axis);// 旋转系数
        return q * source;// 返回目标点
    }
}