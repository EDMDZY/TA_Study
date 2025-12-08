Shader "Unlit/BlackHole"
{
    Properties
    {
        _MainTex ("吸积盘纹理", 2D) = "white" {}
        _SkyCube("天空盒", Cube) = "white" {}
        _HoleRadian("事件视界半径", Float) = 0.1
        _DiskRadian("吸积盘半径", Float) = 0.8
        _DistortionH("光线扭曲强度", Float) = 0.1
        _DistortionP("扭曲衰减系数", Float) = 3
        _RotationSpeed("旋转速度", Float) = 3
        _DiskSteps("吸积盘步数", Int) = 12
        _DiskBrightness("吸积盘亮度", Range(0.1, 10)) = 1.0  // 新增亮度控制
        _DiskThickness("吸积盘厚度", Range(0.01, 1)) = 0.1    // 新增厚度控制
        _DiskUVScale("吸积盘UV缩放", Float) = 1.0            // 新增UV缩放控制
    }
    
    SubShader
    {
        Tags
        {
            "Queue"="Transparent" 
            "IgnoreProjector"="True" 
            "RenderType"="Transparent"
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            #define MAX_DIST 100.0
            #define MAX_STEP 1400
            #define MIN_DIST 0.001
            #define EFFECT_RADIAN 1
            #define PI 3.1415926

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 cameraPos_WS : TEXCOORD1;
                float3 hitPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            samplerCUBE _SkyCube;
            float4 _SkyCube_HDR;
            float _HoleRadian;
            float _DiskRadian;
            float _DistortionH;
            float _DistortionP;
            float _RotationSpeed;
            int _DiskSteps;
            float _DiskSize;
            float _DiskBrightness;
            float _DiskThickness;
            float _DiskUVScale;

            // 判断是否在黑洞事件视界内
            bool InHole(float3 p) { return length(p.xz) < _HoleRadian; }

            // 判断是否在吸积盘范围内
            bool InDisk(float3 p) { return length(p.xz) < _DiskRadian; }

            // 改进的吸积盘渲染函数（使用_MainTex采样）
            float4 RaymarchDisk(float3 ray, float3 zeroPos)
            {
                if (InHole(zeroPos))
                {
                    return float4(0,0,0,1);
                }
                
                float3 position = zeroPos;      
                float lengthPos = length(position.xz);
                
                // 根据厚度调整步长
                float dist = _DiskThickness * (1.0 / _DiskSteps) / abs(ray.y);
                
                position += dist * _DiskSteps * ray * 0.5;     

                // 计算红移效果
                float2 deltaPos = normalize(float2(-zeroPos.z, zeroPos.x));
                float parallel = dot(ray.xz, deltaPos);
                parallel /= sqrt(lengthPos);
                parallel *= 0.5;
                float redShift = parallel + 0.3;
                redShift = clamp(redShift * redShift, 0., 1.);
                
                float4 o = float4(0., 0., 0., 0.);

                [loop]
                for(int i = 0; i < _DiskSteps; i++)
                {                      
                    position -= dist * ray;  
                    float intensity = 1.0 - abs((i - _DiskSteps/2) * (2.0 / _DiskSteps));
                    
                    lengthPos = length(position.xz);
                    
                    // 计算UV坐标（基于位置和旋转）
                    float2 diskUV;
                    float rot = _Time.y * _RotationSpeed;
                    diskUV.x = (-position.z * sin(rot) + position.x * cos(rot)) * _DiskUVScale;
                    diskUV.y = (position.x * sin(rot) + position.z * cos(rot)) * _DiskUVScale;
                    
                    // 采样主纹理
                    float4 texCol = tex2D(_MainTex, diskUV * 0.5 + 0.5);
                    
                    // 计算吸积盘边缘衰减
                    float edge = smoothstep(_DiskRadian, _DiskRadian * 0.8, lengthPos);
                    float innerEdge = smoothstep(_HoleRadian * 1.5, _HoleRadian * 2.0, lengthPos);
                    float radialMask = edge * innerEdge;
                    
                    // 计算厚度衰减
                    float thicknessMask = smoothstep(0.0, 0.2, intensity);
                    
                    // 合并所有遮罩
                    float alpha = radialMask * thicknessMask * texCol.a;
                    
                    // 应用亮度
                    float3 col = texCol.rgb * _DiskBrightness;
                    
                    // 添加红移效果
                    col = lerp(col, col * float3(1.5, 0.7, 0.3), redShift);
                    
                    // 混合颜色
                    o.rgb = lerp(o.rgb, col, alpha);
                    o.a = max(o.a, alpha);
                }  
                
                return o;
            }

            // 旋转矩阵计算
            float3x3 rotationMatrix(float3 axis, float angle)
            {
                axis = normalize(axis);
                float s = sin(angle);
                float c = cos(angle);
                float oc = 1.0 - c;

                return float3x3(
                    oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s,
                    oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s,
                    oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c
                );
            }
            
            // 采样天空盒
            fixed4 SampleSky(in float3 rd)
            {
                
                float4 wRd = mul(unity_WorldToObject, float4(rd, 1));
                // 应用旋转
                float3 rotatedDir = mul(rotationMatrix(float3(0, 1, 0), _Time.y * -0.05), wRd);
                float4 skyData = texCUBE(_SkyCube, rotatedDir);
                float3 skyColor = DecodeHDR(skyData, _SkyCube_HDR);
                return fixed4(skyColor, 1);
            }

            // 颜色混合函数
            half4 BlendColor(half4 f, half4 b)
            {
                half3 rgb = lerp(b.rgb, f.rgb, f.a);
                half alpha = 1 - (1 - f.a) * (1 - b.a);
                return half4(rgb, alpha);
            }

            // 计算光线扭曲强度
            float GetDistortion(float d)
            {
                float dt = pow(_DistortionH, _DistortionP) / pow(d, _DistortionP);
                float v = (cos(d * 0.8 * 2 * PI) + 1) / 2;
                if (d * 0.8 > 1) v = 0;
                return dt * v;
            }

            // 光线步进主函数
            half4 RayMarch(float3 ro, float3 rd)
            {
                half4 color = half4(0, 0, 0, 0);
                float3 core = float3(0, 0, 0);
                
                float d = length(core - ro) - EFFECT_RADIAN;
                float3 p = ro + d * rd;
                float3 newP;
                
                for (int i = 0; i < MAX_STEP; i++)
                {
                    d = length(p - core);
                    float distortion = GetDistortion(d);
                    rd = normalize(rd + distortion * normalize(core - p));
                    newP = p + MIN_DIST * rd;
                    
                    // 使用改进的吸积盘渲染
                    if (p.y * newP.y <= 0)
                    {
                        float3 interP = lerp(p, newP, newP.y / (newP.y - p.y));
                        if (InDisk(interP))
                        {
                            half4 diskCol = RaymarchDisk(rd, interP);
                            color = BlendColor(color, diskCol);
                        }
                    }
                    p = newP;
                }
                
                color = BlendColor(color, SampleSky(rd));
                return color;
            }

            

            // 顶点着色器
            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.cameraPos_WS = mul(unity_ObjectToWorld, float4(_WorldSpaceCameraPos, 1)).xyz;
                o.hitPos = v.vertex;

                return o;
            }

            // 片段着色器
            half4 frag(v2f i) : SV_Target
            {
                float3 ro = i.cameraPos_WS;
                float3 rd = normalize(i.hitPos - ro);
                half4 col = RayMarch(ro, rd);
                return col;
            }
            ENDCG
        }
    }
}