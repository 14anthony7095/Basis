// inspired by https://github.com/netri/Neitri-Unity-Shaders

Shader "Ikeiwa/HUD/Overlay/Fullbright"
{
	Properties
	{
		_Color("Tint",Color) = (1,1,1,1)
		_MinBrightness("Minimum Brightness",Range(0,1)) = 0.35

		[Header(Tiles Fade)]
		[Space]
		_TilesTex ("Tile Texture", 2D) = "white" {}
		_ProgressStart ("Progress Start",Range(-0.5,1.5)) = -0.5
		_ProgressEnd ("Progress End",Range(-0.5,1.5)) = 1.5
		_TileSmoothness ("Progress Smoothness",Range(0,0.5)) = 0.3
		_Distortion ("Tiles Distortion",Range(0,2)) = 0.8
	}
	SubShader
	{
		Tags { "Queue" = "Overlay" "RenderType" = "Transparent" }

		Cull Off
		ZTest Off
		ZWrite Off

		GrabPass 
		{ 
			"_ScreenTex"
		}
		
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#include "../Overlays.cginc"

			struct appdata
			{
				float2 uv : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 grabPos : TEXCOORD1;
				float4 screenPos : TEXCOORD2;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			v2f vert (appdata v)
			{
				v2f o;

				UNITY_SETUP_INSTANCE_ID( v );
				UNITY_INITIALIZE_OUTPUT( v2f, o );
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );

				o.vertex = float4(float2(1,-1)*(v.uv*2-1),1,1);
				o.uv = v.uv;
				o.grabPos = ComputeGrabScreenPos(o.vertex);
				o.screenPos = ComputeScreenPos(o.vertex);
				return o;
			}
				
			sampler2D _ScreenTex;
			fixed4 _Color;
			fixed _MinBrightness;

			float GetLuminance(float3 color)
			{
				return dot(color, float3(0.299f, 0.587f, 0.114f));
			}

			float3 HUEtoRGB(in float H)
			{
				float R = abs(H * 6 - 3) - 1;
				float G = 2 - abs(H * 6 - 2);
				float B = 2 - abs(H * 6 - 4);
				return saturate(float3(R,G,B));
			}

			float3 HSVtoRGB(in float3 HSV)
			{
				float3 RGB = HUEtoRGB(HSV.x);
				return ((RGB - 1) * HSV.y + 1) * HSV.z;
			}

			const float Epsilon = 1e-10;
 
			float3 RGBtoHCV(in float3 RGB)
			{
				// Based on work by Sam Hocevar and Emil Persson
				float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
				float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
				float C = Q.x - min(Q.w, Q.y);
				float H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
				return float3(H, C, Q.x);
			}

			float3 RGBtoHSV(in float3 RGB)
			{
				float3 HCV = RGBtoHCV(RGB);
				float S = HCV.y / (HCV.z + Epsilon);
				return float3(HCV.x, S, HCV.z);
			}

			float3 sceneWorldPosition(float2 uv, float2 offset)
			{
				uv += offset;

				float4 clipPos = float4(uv.xy * 2 - 1, 1, 1);
				float4 cameraSpacePos = mul(unity_CameraInvProjection, clipPos);
				float4 worldSpacePos = mul(unity_MatrixInvV, cameraSpacePos);
				float3 viewDir = normalize(worldSpacePos.xyz / worldSpacePos.w - _WorldSpaceCameraPos);

				uv = UnityStereoTransformScreenSpaceTex(uv);

				float depth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, float4(uv,0,1));

				depth = LinearEyeDepth(depth);
			
				return depth * viewDir + _WorldSpaceCameraPos;
			}

			float4 frag (v2f i) : SV_Target
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( i );

				ApplyTiles(i.screenPos);

				//overlay
				fixed4 col = saturate(tex2Dproj(_ScreenTex, i.grabPos));
				col.rgb = RGBtoHSV(col.rgb);
				float pureDark = 1-saturate(ceil(col.b));

				col.b = max(_MinBrightness,col.b);
				if(pureDark>0)
					col.rgb = float3(0,0,_MinBrightness);

				col.rgb = HSVtoRGB(col.rgb);
			
				float2 offset = 1.2 / _ScreenParams.xy; 

				float3 center = sceneWorldPosition(i.uv, float2(0,0));
				float3 right = sceneWorldPosition(i.uv, float2(offset.x, 0));
				float3 up = sceneWorldPosition(i.uv, float2(0, offset.y));

				float3 worldNormal = normalize(cross(up - center, right - center));

				float3 lightDir = normalize(_WorldSpaceCameraPos - center);

				float NdotR = saturate(dot(worldNormal, lightDir));

				col.rgb *= NdotR * _Color.rgb;

				return col;
			}

			ENDCG
		}
	}
}