Shader "Custom/BlackHoleLensing"
{
    Properties
    {
        _GalaxyTex ("Galaxy Cubemap", Cube) = "white" {}
        _FOVScale ("FOV Scale", Float) = 1.0
        _GravitationalLensing ("Gravitational Lensing", Float) = 1.0
        _RenderBlackHole ("Render Black Hole", Float) = 1.0
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows vertex:vert
        #pragma target 3.0

        #include "UnityCG.cginc"

        samplerCUBE _GalaxyTex;
        float _FOVScale;
        float _GravitationalLensing;
        float _RenderBlackHole;

        struct Input
        {
            float2 uv_MainTex;
            float3 worldPos;
            float3 viewDir;
            float3 localPos;
        };

        const float PI = 3.14159265359;
        const float EPSILON = 0.0001;
        const float INFINITY = 1000000.0;

        // 从轴-角构造四元数（Unity内置函数也可用，这里为了兼容性保留）
        float4 quatFromAxisAngle(float3 axis, float angle)
        {
            float4 q;
            float halfAngle = angle * 0.5 * PI / 180.0;
            q.xyz = axis * sin(halfAngle);
            q.w = cos(halfAngle);
            return q;
        }

        // 四元数旋转向量
        float3 rotateVector(float3 v, float3 axis, float angle)
        {
            float4 q = quatFromAxisAngle(axis, angle);
            float4 qConj = float4(-q.xyz, q.w);
            float4 qPos = float4(v, 0);
            float4 qTemp = mul(q, qPos);
            float4 qResult = mul(qTemp, qConj);
            return qResult.xyz;
        }

        // 引力加速度模拟
        float3 accel(float h2, float3 pos)
        {
            float r2 = dot(pos, pos);
            float r5 = pow(r2, 2.5);
            return -1.5 * h2 * pos / r5;
        }

        // 主光线追踪函数（只保留引力透镜和黑洞视界）
        float3 traceColor(float3 pos, float3 dir)
        {
            float3 color = float3(0, 0, 0);
            float alpha = 1.0;
            float STEP_SIZE = 0.1;
            dir *= STEP_SIZE;

            float3 h = cross(pos, dir);
            float h2 = dot(h, h);

            for (int i = 0; i < 300; i++)
            {
                if (_RenderBlackHole > 0.5)
                {
                    // 引力透镜效应
                    if (_GravitationalLensing > 0.5)
                    {
                        float3 acc = accel(h2, pos);
                        dir += acc;
                    }
                    // 到达事件视界（半径=1）
                    if (dot(pos, pos) < 1.0)
                    {
                        return color;
                    }
                }
                pos += dir;
            }

            // 采样天空盒
            dir = rotateVector(dir, float3(0, 1, 0), _Time.y * 10.0);
            color += texCUBE(_GalaxyTex, dir).rgb * alpha;
            return color;
        }

        // 计算 LookAt 矩阵
        float3x3 lookAt(float3 origin, float3 target, float roll)
        {
            float3 rr = float3(sin(roll), cos(roll), 0);
            float3 ww = normalize(target - origin);
            float3 uu = normalize(cross(ww, rr));
            float3 vv = normalize(cross(uu, ww));
            return float3x3(uu, vv, ww);
        }

        // 顶点着色器传递本地坐标
        void vert(inout appdata_full v, out Input o)
        {
                UNITY_INITIALIZE_OUTPUT(Input, o);
            o.localPos = v.vertex.xyz;
        }

        void surf(Input IN, inout SurfaceOutputStandard o)
        {
            // 相机位置（从球体中心向外偏移）
            float3 cameraPos = float3(0, 0, -15);
            float3 target = float3(0, 0, 0);
            float3x3 view = lookAt(cameraPos, target, 0);

            // 计算屏幕方向（基于球体表面）
            float2 uv = IN.localPos.xy * 2.0;
            uv.x *= _ScreenParams.x / _ScreenParams.y;
            float3 dir = normalize(float3(-uv.x * _FOVScale, uv.y * _FOVScale, 1.0));
            dir = mul(view, dir);

            float3 pos = cameraPos;
            float3 finalColor = traceColor(pos, dir);

            o.Albedo = finalColor;
            o.Emission = finalColor;
            o.Metallic = 0;
            o.Smoothness = 0;
            o.Alpha = 1;
        }
        ENDCG
    }
    FallBack "Diffuse"
}