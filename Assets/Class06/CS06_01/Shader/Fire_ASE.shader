// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Fire_ASE"
{
	Properties
	{
		_FireMask("FireMask", 2D) = "white" {}
		_FireCol("FireCol", Color) = (0,0,0,0)
		_LightingIntensity("LightingIntensity", Float) = 1
		_ExcessiveEdges("ExcessiveEdges", Range( 0 , 1)) = 0.558501
		_GradientEndControl("GradientEndControl", Float) = 2
		_Noise("Noise", 2D) = "white" {}
		_NoiseIntensity("NoiseIntensity", Range( 0 , 1)) = 0.1
		_Fire("Fire", 2D) = "white" {}
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[HideInInspector] __dirty( "", Int ) = 1
	}

	SubShader
	{
		Tags{ "RenderType" = "Transparent"  "Queue" = "Transparent+0" "IgnoreProjector" = "True" "IsEmissive" = "true"  }
		Cull Back
		CGINCLUDE
		#include "UnityShaderVariables.cginc"
		#include "UnityPBSLighting.cginc"
		#include "Lighting.cginc"
		#pragma target 3.0
		struct Input
		{
			float2 uv_texcoord;
		};

		uniform float4 _FireCol;
		uniform float _LightingIntensity;
		uniform sampler2D _FireMask;
		SamplerState sampler_FireMask;
		uniform float4 _FireMask_ST;
		uniform float _GradientEndControl;
		uniform sampler2D _Noise;
		SamplerState sampler_Noise;
		uniform float _ExcessiveEdges;
		uniform sampler2D _Fire;
		SamplerState sampler_Fire;
		uniform float4 _Fire_ST;
		uniform float _NoiseIntensity;

		void surf( Input i , inout SurfaceOutputStandard o )
		{
			float4 break39 = ( _FireCol * _LightingIntensity );
			float2 uv_FireMask = i.uv_texcoord * _FireMask_ST.xy + _FireMask_ST.zw;
			float4 tex2DNode18 = tex2D( _FireMask, uv_FireMask );
			float GradientEnd36 = ( ( 1.0 - tex2DNode18.r ) * _GradientEndControl );
			float2 panner12 = ( 1.0 * _Time.y * float4(0,-0.8,0,0).xy + i.uv_texcoord);
			float Noise27 = tex2D( _Noise, panner12 ).r;
			float4 appendResult41 = (float4(break39.r , ( break39.g + ( GradientEnd36 * Noise27 ) ) , break39.b , 0.0));
			float4 FireCol56 = appendResult41;
			o.Emission = FireCol56.xyz;
			float clampResult24 = clamp( ( Noise27 - _ExcessiveEdges ) , 0.0 , 1.0 );
			float Gradient26 = tex2DNode18.r;
			float smoothstepResult19 = smoothstep( clampResult24 , Noise27 , Gradient26);
			float ExcessiveEdges59 = smoothstepResult19;
			float2 uv_Fire = i.uv_texcoord * _Fire_ST.xy + _Fire_ST.zw;
			float4 tex2DNode64 = tex2D( _Fire, ( uv_Fire + ( (Noise27*2.0 + -1.0) * _NoiseIntensity * GradientEnd36 ) ) );
			float clampResult78 = clamp( ( tex2DNode64.r * tex2DNode64.r ) , 0.0 , 1.0 );
			o.Alpha = ( ExcessiveEdges59 * clampResult78 );
		}

		ENDCG
		CGPROGRAM
		#pragma surface surf Standard alpha:fade keepalpha fullforwardshadows 

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
				float2 customPack1 : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
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
				Input customInputData;
				float3 worldPos = mul( unity_ObjectToWorld, v.vertex ).xyz;
				half3 worldNormal = UnityObjectToWorldNormal( v.normal );
				o.customPack1.xy = customInputData.uv_texcoord;
				o.customPack1.xy = v.texcoord;
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
				surfIN.uv_texcoord = IN.customPack1.xy;
				float3 worldPos = IN.worldPos;
				half3 worldViewDir = normalize( UnityWorldSpaceViewDir( worldPos ) );
				SurfaceOutputStandard o;
				UNITY_INITIALIZE_OUTPUT( SurfaceOutputStandard, o )
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
791.2;105.6;1261.6;801.4;-41.32343;108.6947;1;False;False
Node;AmplifyShaderEditor.CommentaryNode;62;-3026.451,-301.905;Inherit;False;1842.765;487.35;FireMask;7;4;18;34;32;33;36;26;FireMask;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;63;-2253.489,353.1889;Inherit;False;1070.664;400.2456;Noise;5;11;14;12;9;27;Noise;1,1,1,1;0;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;4;-2735.649,-232.0799;Inherit;False;0;18;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TextureCoordinatesNode;11;-2203.489,403.1889;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.Vector4Node;14;-2177.672,544.4348;Inherit;False;Constant;_Vector0;Vector 0;2;0;Create;True;0;0;False;0;False;0,-0.8,0,0;0,0,0,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;18;-2253.897,-251.9051;Inherit;True;Property;_FireMask;FireMask;0;0;Create;True;0;0;False;0;False;-1;7973300a1a076c4418f6106ad19253b9;7973300a1a076c4418f6106ad19253b9;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.PannerNode;12;-1934.667,456.346;Inherit;False;3;0;FLOAT2;0,0;False;2;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.OneMinusNode;32;-1800.138,-140.6746;Inherit;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;9;-1724.635,428.2397;Inherit;True;Property;_Noise;Noise;5;0;Create;True;0;0;False;0;False;-1;832e9088dd4f5744c912ee020175c49e;394f2efb34467754d914529d5fb7e998;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;34;-1839.816,70.04494;Inherit;False;Property;_GradientEndControl;GradientEndControl;4;0;Create;True;0;0;False;0;False;2;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;27;-1407.626,449.7495;Inherit;True;Noise;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;33;-1621.417,-141.4747;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.CommentaryNode;57;-1027.688,-306.0929;Inherit;False;1358.828;527.7964;FireCol;10;17;38;45;46;37;44;39;42;41;56;FireCol;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;60;-1011.693,351.4939;Inherit;False;1297.121;387.8222;ExcessiveEdges;8;30;20;29;31;24;19;21;59;ExcessiveEdges;1,1,1,1;0;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;36;-1389.25,-48.59286;Inherit;True;GradientEnd;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;66;-1092.633,1056.639;Inherit;True;27;Noise;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;72;-841.7418,1057.639;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;2;False;2;FLOAT;-1;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;17;-977.6882,-256.0929;Inherit;False;Property;_FireCol;FireCol;1;0;Create;True;0;0;False;0;False;0,0,0,0;0,0,0,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;21;-1005.373,555.1103;Inherit;False;Property;_ExcessiveEdges;ExcessiveEdges;3;0;Create;True;0;0;False;0;False;0.558501;0.109992;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;38;-959.4664,-91.26806;Inherit;False;Property;_LightingIntensity;LightingIntensity;2;0;Create;True;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;30;-902.4465,467.8218;Inherit;False;27;Noise;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;75;-856.4241,1291.211;Inherit;True;36;GradientEnd;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;67;-900.916,1179.62;Inherit;False;Property;_NoiseIntensity;NoiseIntensity;6;0;Create;True;0;0;False;0;False;0.1;0.1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;46;-945.9881,89.20567;Inherit;True;27;Noise;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;37;-692.9241,-247.3855;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;45;-715.4393,-68.34875;Inherit;True;36;GradientEnd;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;68;-697.8122,924.2138;Inherit;False;0;64;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RegisterLocalVarNode;26;-1399.372,-275.7721;Inherit;True;Gradient;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;20;-714.3194,491.9989;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;69;-546.3719,1085.443;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.BreakToComponentsNode;39;-532.1149,-245.7855;Inherit;False;COLOR;1;0;COLOR;0,0,0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.GetLocalVarNode;31;-419.6532,561.4989;Inherit;True;27;Noise;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;44;-489.2016,-31.69647;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;70;-390.1923,929.3598;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.GetLocalVarNode;29;-401.6689,357.9944;Inherit;True;26;Gradient;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.ClampOpNode;24;-587.7433,490.3186;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;42;-243.5687,-104.3695;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SmoothstepOpNode;19;-182.9996,457.2945;Inherit;True;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;64;-209.576,900.6744;Inherit;True;Property;_Fire;Fire;7;0;Create;True;0;0;False;0;False;-1;600b4e019d8141848ba3c86b49e2bed6;600b4e019d8141848ba3c86b49e2bed6;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RegisterLocalVarNode;59;48.62804,458.8078;Inherit;True;ExcessiveEdges;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;74;93.99546,920.5908;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;41;-92.57118,-246.1162;Inherit;False;FLOAT4;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.ClampOpNode;78;255.8053,916.5768;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;61;451.3981,287.89;Inherit;True;59;ExcessiveEdges;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;56;106.3395,-247.6165;Inherit;True;FireCol;-1;True;1;0;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;65;718.1054,365.6947;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;58;640.9747,-24.38029;Inherit;True;56;FireCol;1;0;OBJECT;;False;1;FLOAT4;0
Node;AmplifyShaderEditor.StandardSurfaceOutputNode;3;1162.364,-40.67297;Float;False;True;-1;2;ASEMaterialInspector;0;0;Standard;Fire_ASE;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;False;False;False;False;False;False;Back;0;False;-1;0;False;-1;False;0;False;-1;0;False;-1;False;0;Transparent;0.5;True;True;0;False;Transparent;;Transparent;All;14;all;True;True;True;True;0;False;-1;False;0;False;-1;255;False;-1;255;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;False;2;15;10;25;False;0.5;True;2;5;False;-1;10;False;-1;0;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;0;0,0,0,0;VertexOffset;True;False;Cylindrical;False;Relative;0;;-1;-1;-1;-1;0;False;0;0;False;-1;-1;0;False;-1;0;0;0;False;0.1;False;-1;0;False;-1;False;16;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT;0;False;9;FLOAT;0;False;10;FLOAT;0;False;13;FLOAT3;0,0,0;False;11;FLOAT3;0,0,0;False;12;FLOAT3;0,0,0;False;14;FLOAT4;0,0,0,0;False;15;FLOAT3;0,0,0;False;0
WireConnection;18;1;4;0
WireConnection;12;0;11;0
WireConnection;12;2;14;0
WireConnection;32;0;18;1
WireConnection;9;1;12;0
WireConnection;27;0;9;1
WireConnection;33;0;32;0
WireConnection;33;1;34;0
WireConnection;36;0;33;0
WireConnection;72;0;66;0
WireConnection;37;0;17;0
WireConnection;37;1;38;0
WireConnection;26;0;18;1
WireConnection;20;0;30;0
WireConnection;20;1;21;0
WireConnection;69;0;72;0
WireConnection;69;1;67;0
WireConnection;69;2;75;0
WireConnection;39;0;37;0
WireConnection;44;0;45;0
WireConnection;44;1;46;0
WireConnection;70;0;68;0
WireConnection;70;1;69;0
WireConnection;24;0;20;0
WireConnection;42;0;39;1
WireConnection;42;1;44;0
WireConnection;19;0;29;0
WireConnection;19;1;24;0
WireConnection;19;2;31;0
WireConnection;64;1;70;0
WireConnection;59;0;19;0
WireConnection;74;0;64;1
WireConnection;74;1;64;1
WireConnection;41;0;39;0
WireConnection;41;1;42;0
WireConnection;41;2;39;2
WireConnection;78;0;74;0
WireConnection;56;0;41;0
WireConnection;65;0;61;0
WireConnection;65;1;78;0
WireConnection;3;2;58;0
WireConnection;3;9;65;0
ASEEND*/
//CHKSM=8FF7DFF78563611ED94239D6C6BD934749BEC76F