// inspired by https://github.com/netri/Neitri-Unity-Shaders

Shader "Ikeiwa/HUD/Overlay/Wireframe"
{
	Properties
	{
		_WireframeColor("Wireframe Color", Color) = (1, 1, 1, 1)
		_BackgroundColor("Background Color", Color) = (0, 0, 0, 1)

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

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#include "../Overlays.cginc"

			struct appdata
			{
				float4 vertex :POSITION;
				float2 uv : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 screenPos : TEXCOORD1;
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
				o.screenPos = ComputeScreenPos(o.vertex);
				return o;
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

			fixed4 frag (v2f i) : SV_Target
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( i );

				ApplyTiles(i.screenPos);

				//world normal calculation
				float2 offset = 1.2 / _ScreenParams.xy; 

				float3 center = sceneWorldPosition(i.uv, float2(0,0));
				float3 right = sceneWorldPosition(i.uv, float2(offset.x, 0));
				float3 up = sceneWorldPosition(i.uv, float2(0, offset.y));

				float3 worldNormal = normalize(cross(up - center, right - center));

				return float4(worldNormal, 1.0f);
			}

			ENDCG
		}

		GrabPass 
		{ 
			"_WorldNormal"
		}

		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#include "../Overlays.cginc"

			struct appdata
			{
				float4 vertex :POSITION;
				float2 uv : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 grabPos : TEXCOORD0;
				float2 uv : TEXCOORD1;
				float4 screenPos : TEXCOORD2;
				float4 pos : SV_POSITION;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert(appdata v) 
			{
				v2f o;
				
				UNITY_SETUP_INSTANCE_ID( v );
				UNITY_INITIALIZE_OUTPUT( v2f, o );
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );

				o.pos = float4(float2(1,-1)*(v.uv*2-1),1,1);
				o.grabPos = ComputeGrabScreenPos(o.pos);
				o.uv = v.uv;
				o.screenPos = ComputeScreenPos(o.pos);
				return o;
			}

			sampler2D _WorldNormal;

			fixed4 _BackgroundColor;
			fixed4 _WireframeColor;

			fixed4 frag(v2f i) : SV_Target
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( i );

				ApplyTiles(i.screenPos);

				//overlay
				float2 grabPos = i.grabPos.xy / i.grabPos.w;

				float2 offset = 1.0 / _ScreenParams.xy;

				float3 center = tex2D(_WorldNormal, grabPos).rgb;
				float3 right = tex2D(_WorldNormal, grabPos + float2(offset.x, 0)).rgb;
				float3 up = tex2D(_WorldNormal, grabPos + float2(0, offset.y)).rgb;

				float wireframe = dot(1, abs(right - center)) + dot(1, abs(up - center));

				float4 col = lerp(_BackgroundColor, _WireframeColor, saturate(wireframe));
				col.a = 1;

				return col;
			}
			ENDCG
		}

	}
}
