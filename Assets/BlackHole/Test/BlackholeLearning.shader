// ============================================
// 黑洞渲染 Shader - Unity 完整版
// 功能：光线步进 + 引力透镜 + 吸积盘噪声
// 使用方法：创建材质，拖到这个 Shader，赋值 Cubemap
// ============================================

Shader "Unlit/BlackholeComplete"
{
    Properties
    {
        // 银河立方体贴图
        _Galaxy ("Galaxy Cubemap", CUBE) = "" {}

        // ========== 可调节参数（在材质面板实时调整）==========
        _FovScale ("FOV Scale", Range(0.5, 2.0)) = 1.0
        _GravitationalLensing ("Gravitational Lensing", Range(0, 1)) = 1.0
        _RenderBlackHole ("Render Black Hole", Range(0, 1)) = 1.0

        // 吸积盘参数
        _AdiskEnabled ("Enable Accretion Disk", Range(0, 1)) = 1.0
        _AdiskHeight ("Disk Height", Range(0.05, 1.0)) = 0.2
        _AdiskBrightness ("Disk Brightness", Range(0, 2.0)) = 0.5
        _AdiskSpeed ("Rotation Speed", Range(0, 2.0)) = 0.5
        _AdiskNoiseScale ("Noise Scale", Range(0.5, 5.0)) = 1.0

        // 颜色控制
        _InnerColor ("Inner Color", Color) = (1, 0.2, 0.1, 1)
        _OuterColor ("Outer Color", Color) = (0.1, 0.3, 1, 1)

        // 相机控制
        _CameraSpeed ("Camera Speed", Range(0, 2)) = 0.1
        _MouseControl ("Mouse Control", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "Queue"="Geometry"
        }
        LOD 100


        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            // ========== 输入变量 ==========
            samplerCUBE _Galaxy;

            // 材质参数
            float _FovScale;
            float _GravitationalLensing;
            float _RenderBlackHole;
            float _AdiskEnabled;
            float _AdiskHeight;
            float _AdiskBrightness;
            float _AdiskSpeed;
            float _AdiskNoiseScale;
            float3 _InnerColor;
            float3 _OuterColor;
            float _CameraSpeed;
            float _MouseControl;

            // Unity 内置变量
            //float4 _ScreenParams;  // x=width, y=height, z=1+1/width, w=1+1/height

            // ========== 数学常量 ==========
            #define PI 3.14159265359
            #define EPSILON 0.0001
            #define INFINITY 1000000.0
            #define STEP_SIZE 0.1
            #define MAX_STEPS 200

            // ========== 顶点着色器 ==========
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD1;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            // ============================================================
            // 1. Simplex 3D 噪声函数（用于吸积盘纹理）
            // ============================================================
            float4 permute(float4 x) { return fmod(((x * 34.0) + 1.0) * x, 289.0); }
            float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

            float snoise(float3 v)
            {
                float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
                float4 D = float4(0.0, 0.5, 1.0, 2.0);

                // 第一角
                float3 i = floor(v + dot(v, C.yyy));
                float3 x0 = v - i + dot(i, C.xxx);

                // 其他角
                float3 g = step(x0.yzx, x0.xyz);
                float3 l = 1.0 - g;
                float3 i1 = min(g.xyz, l.zxy);
                float3 i2 = max(g.xyz, l.zxy);

                float3 x1 = x0 - i1 + 1.0 * C.xxx;
                float3 x2 = x0 - i2 + 2.0 * C.xxx;
                float3 x3 = x0 - 1.0 + 3.0 * C.xxx;

                i = fmod(i, 289.0);
                float4 p = permute(permute(permute(i.z + float4(0.0, i1.z, i2.z, 1.0)) +
                        i.y + float4(0.0, i1.y, i2.y, 1.0)) +
                    i.x + float4(0.0, i1.x, i2.x, 1.0));

                float n_ = 1.0 / 7.0;
                float3 ns = n_ * D.wyz - D.xzx;

                float4 j = p - 49.0 * floor(p * ns.z * ns.z);

                float4 x_ = floor(j * ns.z);
                float4 y_ = floor(j - 7.0 * x_);

                float4 x = x_ * ns.x + ns.yyyy;
                float4 y = y_ * ns.x + ns.yyyy;
                float4 h = 1.0 - abs(x) - abs(y);

                float4 b0 = float4(x.xy, y.xy);
                float4 b1 = float4(x.zw, y.zw);

                float4 s0 = floor(b0) * 2.0 + 1.0;
                float4 s1 = floor(b1) * 2.0 + 1.0;
                float4 sh = -step(h, float4(0, 0, 0, 0));

                float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
                float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

                float3 p0 = float3(a0.xy, h.x);
                float3 p1 = float3(a0.zw, h.y);
                float3 p2 = float3(a1.xy, h.z);
                float3 p3 = float3(a1.zw, h.w);

                float4 norm = taylorInvSqrt(float4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
                p0 *= norm.x;
                p1 *= norm.y;
                p2 *= norm.z;
                p3 *= norm.w;

                float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
                m = m * m;
                return 42.0 * dot(m * m, float4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
            }

            // ============================================================
            // 2. 引力加速度计算
            // ============================================================
            // h2: 角动量平方（常数）
            // pos: 当前位置
            // 返回：加速度向量
            float3 accel(float h2, float3 pos)
            {
                float r2 = dot(pos, pos); // 距离平方
                float r5 = pow(r2, 2.5); // r^5 = (r^2)^(2.5)
                // 引力加速度 = -1.5 * 角动量² * 位置向量 / r⁵
                // 这个公式来自：a = -GM/r²，但这里简化为 a ∝ 1/r³
                return -1.5 * h2 * pos / r5;
            }

            // ============================================================
            // 3. 四元数旋转（用于旋转银河背景）
            // ============================================================
            float4 quatFromAxisAngle(float3 axis, float angle)
            {
                float halfAngle = radians(angle) * 0.5;
                float s = sin(halfAngle);
                return float4(axis.x * s, axis.y * s, axis.z * s, cos(halfAngle));
            }

            float4 quatConj(float4 q)
            {
                return float4(-q.x, -q.y, -q.z, q.w);
            }

            float4 quatMul(float4 q1, float4 q2)
            {
                return float4(
                    q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
                    q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
                    q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w,
                    q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z
                );
            }

            float3 rotateVector(float3 v, float3 axis, float angle)
            {
                float4 q = quatFromAxisAngle(axis, angle);
                float4 qConj = quatConj(q);
                float4 qv = float4(v.x, v.y, v.z, 0);
                float4 rotated = quatMul(quatMul(q, qv), qConj);
                return rotated.xyz;
            }

            // ============================================================
            // 4. 球坐标转换
            // ============================================================
            // 输入：笛卡尔坐标 (x,y,z)
            // 输出：(rho, theta, phi) 其中：
            //   rho = 径向距离
            //   theta = 方位角（绕Y轴）
            //   phi = 极角（上下）
            float3 toSpherical(float3 p)
            {
                float rho = length(p);
                float theta = atan2(p.z, p.x);
                float phi = asin(p.y / rho);
                return float3(rho, theta, phi);
            }

            // ============================================================
            // 5. 观察矩阵（让相机始终看向黑洞）
            // ============================================================
            float3x3 lookAt(float3 origin, float3 target, float roll)
            {
                float3 rr = float3(sin(roll), cos(roll), 0);
                float3 ww = normalize(target - origin); // 前向
                float3 uu = normalize(cross(ww, rr)); // 右向
                float3 vv = cross(uu, ww); // 上向
                return float3x3(-uu, vv, ww);
            }

            // ============================================================
            // 6. 吸积盘颜色计算（核心视觉效果）
            // ============================================================
            void adiskColor(float3 pos, inout float3 color, float time, float3 oripos)
            {
                float innerRadius = 2.6; // 内半径（最内稳定轨道）
                float outerRadius = 12.0; // 外半径

                // ===== 密度计算 =====
                // 基础密度：在圆盘区域内为1，边缘衰减到0
                float3 normalizedPos = pos / float3(outerRadius, _AdiskHeight, outerRadius);
                float density = max(0.0, 1.0 - length(normalizedPos));
                if (density < 0.001) return;

                // 垂直方向密度衰减（盘越靠边缘越薄）
                density *= pow(1.0 - abs(pos.y) / _AdiskHeight, 1.0);

                // 内半径以内没有物质（黑洞吞噬区域）
                density *= smoothstep(innerRadius, innerRadius * 1.1, length(pos));
                if (density < 0.001) return;

                // ===== 转换为球坐标用于噪声 =====
                float3 spherical = toSpherical(pos);
                spherical.y *= 2.0; // 拉伸方位角
                spherical.z *= 4.0; // 拉伸极角

                // 径向密度衰减（越往外越稀疏）
                density *= 1.0 / pow(spherical.x, 1.0);
                density *= 500.0; // 强度系数

                // ===== 多层噪声生成纹理 =====
                float noise = 1.0;
                float3 noiseCoord = spherical;

                // 5层噪声叠加，产生复杂的湍流效果
                for (int i = 0; i < 5; i++)
                {
                    float freq = pow(float(i + 1), 2.0) * _AdiskNoiseScale;
                    noise *= 0.5 * snoise(noiseCoord * freq) + 0.5;

                    // 奇偶层旋转方向相反 → 产生剪切流动效果
                    if (i % 2 == 0)
                        noiseCoord.y += time * _AdiskSpeed;
                    else
                        noiseCoord.y -= time * _AdiskSpeed;
                }

                // ===== 视角相关的颜色（产生彩虹色效果）=====
                oripos = normalize(oripos);
                float3 v1 = -oripos;
                float3 v2 = normalize(pos);
                float invariance = dot(float3(0, 1, 0), cross(v1, v2));
                float sgn = sign(invariance);
                invariance = abs(invariance);
                invariance = pow(invariance, 0.7);

                // 根据视角混合红/绿/蓝
                float t = spherical.x / outerRadius;
                float3 diskColor;
                diskColor.r = 0.5 - t * invariance * 0.5 * sgn;
                diskColor.g = 0.5 - t * invariance * 0.5;
                diskColor.b = 0.5 + t * invariance * 0.5 * sgn;

                // 根据半径混合内圈和外圈颜色
                float3 radialColor = lerp(_InnerColor, _OuterColor, t);
                diskColor *= radialColor;

                // 最终颜色 = 密度 × 亮度 × 噪声 × 视角颜色
                color += density * _AdiskBrightness * diskColor * abs(noise);
            }

            // ============================================================
            // 7. 光线追踪主函数（核心渲染循环）
            // ============================================================
            float3 traceColor(float3 pos, float3 dir, float2 uv, float time)
            {
                float3 color = float3(0, 0, 0);
                float3 originalPos = pos;

                // 计算初始角动量（用于引力计算）
                float3 h = cross(pos, dir);
                float h2 = dot(h, h);

                // 光线步进循环
                for (int step = 0; step < MAX_STEPS; step++)
                {
                    if (_RenderBlackHole > 0.5)
                    {
                        // ===== 引力透镜：光线被黑洞弯曲 =====
                        if (_GravitationalLensing > 0.5)
                        {
                            float3 acc = accel(h2, pos);
                            dir += acc * STEP_SIZE; // 应用加速度
                        }

                        // ===== 事件视界：光线被黑洞捕获 =====
                        // 半径小于1.0时，光线永远无法逃逸
                        if (dot(pos, pos) < 1.0)
                        {
                            return color; // 返回黑色（黑洞）
                        }

                        // ===== 吸积盘：累积物质发出的光 =====
                        if (_AdiskEnabled > 0.5)
                        {
                            adiskColor(pos, color, time, originalPos);
                        }
                    }

                    // 光线步进
                    pos += dir * STEP_SIZE;
                }

                // ===== 背景：银河立方体贴图 =====
                // 让银河缓慢旋转
                dir = rotateVector(normalize(dir), float3(0, 1, 0), time * 5.0);
                color += texCUBE(_Galaxy, dir).rgb;

                return color;
            }

            // ============================================================
// 8. 片段着色器（主入口）
// ============================================================
fixed4 frag (v2f i) : SV_Target
{
    // ===== 计算屏幕UV（范围[-1, 1]，修正宽高比）=====
    float2 uv = i.uv - 0.5;
    uv.x *= _ScreenParams.x / _ScreenParams.y;
    
    // ===== 获取时间 =====
    float time = _Time.y * _CameraSpeed;
    
    // ===== 相机位置和方向 =====
    float3 cameraPos = _WorldSpaceCameraPos;
    float3 forward = normalize(float3(0, 0, 0) - cameraPos);  // 指向黑洞方向
    
    // ===== 构建简单的观察矩阵 =====
    float3 worldUp = float3(0, 1, 0);
    float3 right = normalize(cross(worldUp, forward));
    float3 up = cross(forward, right);
    
    // ===== 生成射线方向（在相机空间）=====
    float3 dir = normalize(float3(uv.x * _FovScale, uv.y * _FovScale, 1.0));
    
    // ===== 转换到世界空间 =====
    float3x3 viewMatrix = float3x3(right, up, forward);
    dir = mul(viewMatrix, dir);
    
    // ===== 执行光线追踪 =====
    float3 color = traceColor(cameraPos, dir, uv, time);
    
    return fixed4(color, 1.0);
}
            ENDCG
        }
    }
}