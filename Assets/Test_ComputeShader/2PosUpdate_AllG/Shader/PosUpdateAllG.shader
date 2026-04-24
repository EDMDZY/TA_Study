Shader "Unlit/PosUpdateAllG"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // Unity自动从MaterialPropertyBlock读取矩阵
            // 你不需要写任何矩阵代码
            #pragma multi_compile_instancing    // 正常GPU Instancing
            // Unity GPU Instancing的核心指令，让你可以手动控制每个实例的变换数据来源
            // procedural表示使用程序化方式提供实例数据（而不是从MaterialPropertyBlock）
            #pragma instancing_options procedural:setup //Procedural模式GPU Instancing
            
            #include "UnityCG.cginc"
            
            StructuredBuffer<float3> _ParticlePositions;
            float4 _Color;
            
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            void setup()
            {
                // UNITY_ACCESS_INSTANCED_PROP 用于访问MaterialPropertyBlock数据
                // 但使用procedural时，通常不需要这个,且必须手动设置unity_ObjectToWorld
                // 因为Unity没有任何内置API能直接从 StructuredBuffer<float3> 设置物体位置
                // 从缓冲区读取实例位置
                #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
                float3 pos = _ParticlePositions[unity_InstanceID];
                unity_ObjectToWorld = float4x4(
                    1,0,0,pos.x,
                    0,1,0,pos.y,
                    0,0,1,pos.z,
                    0,0,0,1
                );
                #endif
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.vertex = UnityWorldToClipPos(worldPos);
                o.normal = mul(unity_ObjectToWorld, v.normal);
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                return _Color;
            }
            ENDCG
        }
    }
}
