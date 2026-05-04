Shader "Hidden/CustomBloom"
{
	CGINCLUDE
	#include "UnityCG.cginc"

	sampler2D _MainTex;
	float4 _MainTex_TexelSize;
	// 偏移量系数，控制采样距离
	float _Offset;
	float _Threshold;
	sampler2D _BloomTex;
	float _Intensity;

	// ========== 降采样顶点着色器输出结构 ==========
	struct v2f_DownSample
	{
		float4 pos: SV_POSITION;      // 裁剪空间位置
		float2 uv: TEXCOORD1;         // 中心点UV坐标
		float4 uv01: TEXCOORD2;       // 两组对角UV（左上/右下）
		float4 uv23: TEXCOORD3;       // 两组对角UV（右上/左下）
	};
	
	// ========== 升采样顶点着色器输出结构 ==========
	struct v2f_UpSample
	{
		float4 pos: SV_POSITION;      // 裁剪空间位置
		float4 uv01: TEXCOORD1;       // 采样点组1（2个点）
		float4 uv23: TEXCOORD2;       // 采样点组2（2个点）
		float4 uv45: TEXCOORD3;       // 采样点组3（2个点）
		float4 uv67: TEXCOORD4;       // 采样点组4（2个点）
	};

	//阈值
	half4 frag_PreFilter(v2f_img i) : SV_Target
	{
		half4 color = tex2D(_MainTex, i.uv);

		// 抠出发光区域
		float br = max(max(color.r, color.g), color.b);			// 拿到最大的颜色分量
		br = max(0.0f, (br - _Threshold)) / max(br,0.00001f);	// 把亮的部分取到，并且限制（除法作用）
		color.rgb *= br;
		return color;
	}
  
	// ========== 降采样顶点着色器 ==========
	// 功能：计算中心点及4个对角方向的采样UV坐标
	v2f_DownSample Vert_DownSample(appdata_img v)
	{
		v2f_DownSample o;
		// 将顶点从模型空间转换到裁剪空间
		o.pos = UnityObjectToClipPos(v.vertex);
		float2 uv = v.texcoord;
		o.uv = uv;  // 保存中心UV

		// 纹素大小乘以0.5，使采样范围缩小一半（用于降采样）
		float4 texelSize = 0.5 * _MainTex_TexelSize;
		float2 offset = float2(1.0 + _Offset, 1.0 + _Offset);
		
		// 计算四个对角方向的UV坐标
		// 公式：UV = 中心UV ± 纹素大小 × (1+偏移量)
		
		// uv01.xy: 右上方向（top right）
		o.uv01.xy = uv - texelSize * offset;
		// uv01.zw: 左下方向（bottom left）
		o.uv01.zw = uv + texelSize * offset;
		
		// uv23.xy: 左上方向（top left）
		o.uv23.xy = uv - float2(texelSize.x, -texelSize.y) * offset;
		// uv23.zw: 右下方向（bottom right）
		o.uv23.zw = uv + float2(texelSize.x, -texelSize.y) * offset;
		
		return o;
	}
	
	// ========== 降采样片段着色器 ==========
	// 功能：采样中心点+4个对角点，加权平均（Kawase模糊核心）
	// 权重：中心点权重4，四个角各权重1，总权重8 → 乘0.125归一化
	half4 frag_DownsampleKawase(v2f_DownSample i): SV_Target
	{
		half4 sum = tex2D(_MainTex, i.uv) * 4;           // 中心点 ×4
		sum += tex2D(_MainTex, i.uv01.xy);               // 右上
		sum += tex2D(_MainTex, i.uv01.zw);               // 左下
		sum += tex2D(_MainTex, i.uv23.xy);               // 左上
		sum += tex2D(_MainTex, i.uv23.zw);               // 右下
		
		return sum * 0.125;  // 除以8，取平均值
	}
	
	// ========== 升采样顶点着色器 ==========
	// 功能：计算8个方向采样点的UV坐标（带不同权重）
	v2f_UpSample Vert_UpSample(appdata_img v)
	{
		v2f_UpSample o;
		o.pos = UnityObjectToClipPos(v.vertex);
	
		float2 uv = v.texcoord;
		
		// 纹素大小乘以0.5
		float4 texelSize = 0.5 * _MainTex_TexelSize;

		// 计算偏移系数（1+偏移量）
		float2 offset = float2(1.0 + _Offset, 1.0 + _Offset);
		
		// 以下计算8个采样方向（类似菱形/八角形分布）
		// 方向1: 左（-2x, 0）
		o.uv01.xy = uv + float2(-texelSize.x * 2, 0) * offset;
		// 方向2: 左上（-x, +y）
		o.uv01.zw = uv + float2(-texelSize.x, texelSize.y) * offset;
		
		// 方向3: 上（0, +2y）
		o.uv23.xy = uv + float2(0, texelSize.y * 2) * offset;
		// 方向4: 右上（+x, +y）
		o.uv23.zw = uv + texelSize * offset;
		
		// 方向5: 右（+2x, 0）
		o.uv45.xy = uv + float2(texelSize.x * 2, 0) * offset;
		// 方向6: 右下（+x, -y）
		o.uv45.zw = uv + float2(texelSize.x, -texelSize.y) * offset;
		
		// 方向7: 下（0, -2y）
		o.uv67.xy = uv + float2(0, -texelSize.y * 2) * offset;
		// 方向8: 左下（-x, -y）
		o.uv67.zw = uv - texelSize * offset;
		
		return o;
	}
	
	// ========== 升采样片段着色器 ==========
	// 功能：采样8个方向，中心方向（轴向）权重2，对角方向权重1
	// 总权重：1+2+1+2+1+2+1+2 = 12 → 乘0.0833（≈1/12）归一化
	half4 frag_UpsampleKawase(v2f_UpSample i): SV_Target
	{
		half4 sum = 0;
		// 轴向采样点（权重1）
		sum += tex2D(_MainTex, i.uv01.xy);
		// 对角采样点（权重2）
		sum += tex2D(_MainTex, i.uv01.zw) * 2;
		
		// 轴向采样点（权重1）
		sum += tex2D(_MainTex, i.uv23.xy);
		// 对角采样点（权重2）
		sum += tex2D(_MainTex, i.uv23.zw) * 2;
		
		// 轴向采样点（权重1）
		sum += tex2D(_MainTex, i.uv45.xy);
		// 对角采样点（权重2）
		sum += tex2D(_MainTex, i.uv45.zw) * 2;
		
		// 轴向采样点（权重1）
		sum += tex2D(_MainTex, i.uv67.xy);
		// 对角采样点（权重2）
		sum += tex2D(_MainTex, i.uv67.zw) * 2;
		
		return sum * 0.0833;  // 约等于1/12，归一化权重
	}

	//合并
	half4 frag_Combine(v2f_img i) : SV_Target
	{
		half4 base_color = tex2D(_MainTex, i.uv);

		half4 bloom_color = tex2D(_BloomTex, i.uv);

		half3 final_color = base_color.rgb + bloom_color.rgb * _Intensity;

		return half4(final_color,1.0);
	}

	ENDCG

	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_BlurOffset("BlurOffset",Float) = 1 
	}
	SubShader
	{
		Cull Off ZWrite Off ZTest Always
		//0 阈值
		Pass
		{
			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag_PreFilter
			ENDCG
		}
		//1 降采样模糊
		Pass
		{
			CGPROGRAM
			#pragma vertex Vert_DownSample
			#pragma fragment frag_DownsampleKawase
			ENDCG
		}
		//2 升采样模糊
		Pass
		{
			CGPROGRAM
			#pragma vertex Vert_UpSample
			#pragma fragment frag_UpsampleKawase
			ENDCG
		}
		//3 合并
		Pass
		{
			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag_Combine
			ENDCG
		}
	}
}
