// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Scan"
{
	Properties
	{
		_RimMin("RimMin", Range( -1 , 1)) = 1
		_RimMax("RimMax", Range( 0 , 2)) = 0
		_InnerCol("InnerCol", Color) = (0.3988536,0.7531028,0.8037735,0)
		_OutCol("OutCol", Color) = (0.3988536,0.7531028,0.8037735,0)
		_OutLightStr("OutLightStr", Float) = 0
		_TextureSample0("Texture Sample 0", 2D) = "white" {}
		_LineStr("LineStr", Float) = 4
		_FlowFillNum("FlowFillNum", Float) = 1
		_Speed("Speed", Vector) = (0,1,0,0)
		[HideInInspector] __dirty( "", Int ) = 1
	}

	SubShader
	{
		Pass
		{
			ColorMask 0
			ZWrite On
		}

		Tags{ "RenderType" = "Custom"  "Queue" = "Transparent+0" "IgnoreProjector" = "True" "IsEmissive" = "true"  }
		Cull Back
		Blend SrcAlpha One
		
		CGINCLUDE
		#include "UnityShaderVariables.cginc"
		#include "UnityPBSLighting.cginc"
		#include "Lighting.cginc"
		#pragma target 3.0
		struct Input
		{
			float3 worldNormal;
			float3 viewDir;
			float3 worldPos;
		};

		uniform float4 _InnerCol;
		uniform float4 _OutCol;
		uniform float _OutLightStr;
		uniform float _RimMin;
		uniform float _RimMax;
		uniform sampler2D _TextureSample0;
		uniform float _FlowFillNum;
		uniform float2 _Speed;
		uniform float _LineStr;

		inline half4 LightingUnlit( SurfaceOutput s, half3 lightDir, half atten )
		{
			return half4 ( 0, 0, 0, s.Alpha );
		}

		void surf( Input i , inout SurfaceOutput o )
		{
			float3 ase_worldNormal = i.worldNormal;
			float dotResult3 = dot( ase_worldNormal , i.viewDir );
			float clampResult4 = clamp( dotResult3 , 0.0 , 1.0 );
			float smoothstepResult6 = smoothstep( _RimMin , _RimMax , ( 1.0 - clampResult4 ));
			float4 lerpResult14 = lerp( _InnerCol , ( _OutCol * _OutLightStr ) , smoothstepResult6);
			float4 FinalRimCol51 = lerpResult14;
			float3 ase_worldPos = i.worldPos;
			float2 appendResult27 = (float2(ase_worldPos.x , ase_worldPos.y));
			float3 objToWorld29 = mul( unity_ObjectToWorld, float4( float3(0,0,0), 1 ) ).xyz;
			float2 appendResult31 = (float2(objToWorld29.x , objToWorld29.y));
			float4 FlowCol47 = ( tex2D( _TextureSample0, ( ( ( appendResult27 - appendResult31 ) * _FlowFillNum ) + ( _Speed * _Time.y ) ) ) * _LineStr );
			o.Emission = ( FinalRimCol51 + FlowCol47 ).rgb;
			float FlowAlpha50 = smoothstepResult6;
			o.Alpha = FlowAlpha50;
		}

		ENDCG
		CGPROGRAM
		#pragma surface surf Unlit keepalpha fullforwardshadows 

		ENDCG
		Pass
		{
			Name "ShadowCaster"
			Tags{ "LightMode" = "ShadowCaster" }
			ZWrite On
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#pragma multi_compile_shadowcaster
			#pragma multi_compile UNITY_PASS_SHADOWCASTER
			#pragma skip_variants FOG_LINEAR FOG_EXP FOG_EXP2
			#include "HLSLSupport.cginc"
			#if ( SHADER_API_D3D11 || SHADER_API_GLCORE || SHADER_API_GLES || SHADER_API_GLES3 || SHADER_API_METAL || SHADER_API_VULKAN )
				#define CAN_SKIP_VPOS
			#endif
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "UnityPBSLighting.cginc"
			sampler3D _DitherMaskLOD;
			struct v2f
			{
				V2F_SHADOW_CASTER;
				float3 worldPos : TEXCOORD1;
				float3 worldNormal : TEXCOORD2;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};
			v2f vert( appdata_full v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID( v );
				UNITY_INITIALIZE_OUTPUT( v2f, o );
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );
				UNITY_TRANSFER_INSTANCE_ID( v, o );
				float3 worldPos = mul( unity_ObjectToWorld, v.vertex ).xyz;
				half3 worldNormal = UnityObjectToWorldNormal( v.normal );
				o.worldNormal = worldNormal;
				o.worldPos = worldPos;
				TRANSFER_SHADOW_CASTER_NORMALOFFSET( o )
				return o;
			}
			half4 frag( v2f IN
			#if !defined( CAN_SKIP_VPOS )
			, UNITY_VPOS_TYPE vpos : VPOS
			#endif
			) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID( IN );
				Input surfIN;
				UNITY_INITIALIZE_OUTPUT( Input, surfIN );
				float3 worldPos = IN.worldPos;
				half3 worldViewDir = normalize( UnityWorldSpaceViewDir( worldPos ) );
				surfIN.viewDir = worldViewDir;
				surfIN.worldPos = worldPos;
				surfIN.worldNormal = IN.worldNormal;
				SurfaceOutput o;
				UNITY_INITIALIZE_OUTPUT( SurfaceOutput, o )
				surf( surfIN, o );
				#if defined( CAN_SKIP_VPOS )
				float2 vpos = IN.pos;
				#endif
				half alphaRef = tex3D( _DitherMaskLOD, float3( vpos.xy * 0.25, o.Alpha * 0.9375 ) ).a;
				clip( alphaRef - 0.01 );
				SHADOW_CASTER_FRAGMENT( IN )
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
	CustomEditor "ASEMaterialInspector"
}
/*ASEBEGIN
Version=18500
235.2;293.6;1393.6;699.8;2739.273;400.4496;3.012571;True;True
Node;AmplifyShaderEditor.CommentaryNode;49;-1581.119,692.145;Inherit;False;2243.227;562.1974;流光;16;19;30;17;29;27;31;32;46;24;35;47;36;18;20;21;43;;1,1,1,1;0;0
Node;AmplifyShaderEditor.Vector3Node;30;-1531.119,945.4454;Inherit;False;Constant;_Vector0;Vector 0;8;0;Create;True;0;0;False;0;False;0,0,0;0,0,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.CommentaryNode;54;-1579.759,-202.3693;Inherit;False;1472.869;845.3628;边缘光;15;1;2;3;4;5;7;8;13;16;15;10;6;14;51;50;;1,1,1,1;0;0
Node;AmplifyShaderEditor.TransformPositionNode;29;-1342.88,948.5652;Inherit;False;Object;World;False;Fast;True;1;0;FLOAT3;0,0,0;False;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.WorldPosInputsNode;17;-1360.088,742.145;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.WorldNormalVector;2;-1529.759,275.739;Inherit;False;False;1;0;FLOAT3;0,0,1;False;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.ViewDirInputsCoordNode;1;-1504.15,414.0901;Inherit;False;World;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.DynamicAppendNode;31;-1119.279,963.1253;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;27;-1119.277,765.5284;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;32;-917.5172,830.8076;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RangedFloatNode;46;-858.2054,959.5294;Inherit;False;Property;_FlowFillNum;FlowFillNum;8;0;Create;True;0;0;False;0;False;1;1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;18;-668.4246,1143.939;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.DotProductOpNode;3;-1279.106,334.9165;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.Vector2Node;20;-656.4938,988.5192;Inherit;False;Property;_Speed;Speed;9;0;Create;True;0;0;False;0;False;0,1;1,0;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;21;-455.8365,1043.66;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;43;-648.7976,833.5178;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ClampOpNode;4;-1121.673,332.6348;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;8;-1035.13,527.5934;Inherit;False;Property;_RimMax;RimMax;2;0;Create;True;0;0;False;0;False;0;0;0;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;7;-1040.73,441.1935;Inherit;False;Property;_RimMin;RimMin;0;0;Create;True;0;0;False;0;False;1;0;-1;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;5;-923.3036,331.6312;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;16;-1041.868,211.8716;Inherit;False;Property;_OutLightStr;OutLightStr;5;0;Create;True;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;13;-1065.61,26.73271;Inherit;False;Property;_OutCol;OutCol;4;0;Create;True;0;0;False;0;False;0.3988536,0.7531028,0.8037735,0;0,0,0,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleAddOpNode;19;-279.1045,835.6078;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ColorNode;10;-1060.743,-152.3693;Inherit;False;Property;_InnerCol;InnerCol;3;0;Create;True;0;0;False;0;False;0.3988536,0.7531028,0.8037735,0;0,0,0,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;15;-830.3076,82.67765;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;36;45.4107,1020.788;Inherit;False;Property;_LineStr;LineStr;7;0;Create;True;0;0;False;0;False;4;4;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SmoothstepOpNode;6;-724.5699,341.8334;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;24;-101.4923,806.6833;Inherit;True;Property;_TextureSample0;Texture Sample 0;6;0;Create;True;0;0;False;0;False;-1;46fc1c608b2213f488667930677e883d;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.LerpOp;14;-521.7197,-20.15894;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;35;240.9514,811.4841;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;51;-331.6895,-24.24097;Inherit;False;FinalRimCol;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;47;437.3082,807.126;Inherit;False;FlowCol;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;48;-49.23539,118.2809;Inherit;False;47;FlowCol;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;52;-60.38543,23.93417;Inherit;False;51;FinalRimCol;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;50;-498.6041,338.5245;Inherit;False;FlowAlpha;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;53;157.0157,220.6597;Inherit;False;50;FlowAlpha;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;34;173.7525,52.04091;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.StandardSurfaceOutputNode;0;484.6184,41.9583;Float;False;True;-1;2;ASEMaterialInspector;0;0;Unlit;Scan;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;False;False;False;False;False;False;Back;0;False;-1;0;False;-1;False;0;False;-1;0;False;-1;True;0;Custom;0.5;True;True;0;True;Custom;;Transparent;All;14;all;True;True;True;True;0;False;-1;False;0;False;-1;255;False;-1;255;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;False;2;15;10;25;False;0.5;True;8;5;False;-1;1;False;-1;0;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;0;0,0,0,0;VertexOffset;True;False;Cylindrical;False;Relative;0;;1;-1;-1;-1;0;False;0;0;False;-1;-1;0;False;-1;0;0;0;False;0.1;False;-1;0;False;-1;False;15;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT;0;False;4;FLOAT;0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT;0;False;9;FLOAT;0;False;10;FLOAT;0;False;13;FLOAT3;0,0,0;False;11;FLOAT3;0,0,0;False;12;FLOAT3;0,0,0;False;14;FLOAT4;0,0,0,0;False;15;FLOAT3;0,0,0;False;0
WireConnection;29;0;30;0
WireConnection;31;0;29;1
WireConnection;31;1;29;2
WireConnection;27;0;17;1
WireConnection;27;1;17;2
WireConnection;32;0;27;0
WireConnection;32;1;31;0
WireConnection;3;0;2;0
WireConnection;3;1;1;0
WireConnection;21;0;20;0
WireConnection;21;1;18;0
WireConnection;43;0;32;0
WireConnection;43;1;46;0
WireConnection;4;0;3;0
WireConnection;5;0;4;0
WireConnection;19;0;43;0
WireConnection;19;1;21;0
WireConnection;15;0;13;0
WireConnection;15;1;16;0
WireConnection;6;0;5;0
WireConnection;6;1;7;0
WireConnection;6;2;8;0
WireConnection;24;1;19;0
WireConnection;14;0;10;0
WireConnection;14;1;15;0
WireConnection;14;2;6;0
WireConnection;35;0;24;0
WireConnection;35;1;36;0
WireConnection;51;0;14;0
WireConnection;47;0;35;0
WireConnection;50;0;6;0
WireConnection;34;0;52;0
WireConnection;34;1;48;0
WireConnection;0;2;34;0
WireConnection;0;9;53;0
ASEEND*/
//CHKSM=CB114F97AC97EAF8F12C33ABAE821C98FB3D98D7