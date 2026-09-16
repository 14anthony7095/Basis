Shader "Ikeiwa/HUD/Overlay/Outline"
{
    Properties
    {
        _DepthTex ("Scene Depth Texture", 2D) = "white" {}
		_BackgroundTint("Background tint",Color) = (1,1,1,1)
		_ShapeFillColor("Shape Fill Color",Color) = (1,1,1,0.25)
		_PatternTex("Pattern Texture", 2D) = "white" {}
		_PatternColor("Pattern Color", Color) = (1,1,1,0)
		_PatternSize("Pattern Size", Vector) = (1,1,0,0)

		[Header(Outline)]
		[Space]
		_ShapeOutlineColor("Shape Outline Color",Color) = (1,1,1,1)
        _OutlineThickness ("Outline Thickness", Float) = 1
        _OutlineDepthMultiplier ("Outline Multiplier", Float) = 5
        _OutlineDepthBias ("Outline Bias", Float) = 1
        _OutlineDensity ("Outline Density", Float) = 1

		[Header(Tiles Fade)]
		[Space]
		_TilesTex ("Tile Texture", 2D) = "white" {}
		_ProgressStart ("Progress Start",Range(-0.5,1.5)) = -0.5
		_ProgressEnd ("Progress End",Range(-0.5,1.5)) = 1.5
		_TileSmoothness ("Progress Smoothness",Range(0,0.5)) = 0.3
		_Distortion ("Tiles Distortion",Range(0,2)) = 0.8

		[Header(Advanced)]
		[Space]
		_CameraNear("Camera Near", Float) = 0.3
		_CameraFar("Camera Far", Float) = 200
        _TessellationUniform( "Tessellation", Range( 1, 64 ) ) = 32
		[Enum(Off,0,On,1)] _ZWrite ("Show Nameplates", Float) = 1
    }
    SubShader
    {
        Tags { "Queue" = "Overlay" "RenderType" = "Transparent" }
        LOD 100
        
		ZTest Off
		ZWrite [_ZWrite]

        Pass
        {
            Blend DstColor Zero

            Stencil
            {
                Ref 43
                Comp Always
                Pass Replace
                ZFail Keep
            }   

            CGPROGRAM
			#pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma fragmentoption ARB_precision_hint_fastest

            #include "UnityCG.cginc"
            #include "../Overlays.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert (appdata v)
            {
                v2f o;
                
				UNITY_SETUP_INSTANCE_ID( v );
				UNITY_INITIALIZE_OUTPUT( v2f, o );
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );

                o.pos = float4(float2(1,-1)*(v.uv*2-1),1,1);
                o.uv = ComputeScreenPos(o.pos);
                return o;
            }

			float4 _BackgroundTint;

			struct fragOutput {
				fixed4 color : SV_Target;
				float depth : SV_Depth;
			};

            fragOutput frag (v2f i)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( i );

                ApplyTiles(i.uv);

				fragOutput o;

				o.color = _BackgroundTint;
				o.depth = 0;

                return o;
            }
            ENDCG
        }

        Pass 
		{  
			Stencil
            {
                Ref 43
                Comp Equal
            } 

            Blend SrcAlpha OneMinusSrcAlpha 

			CGPROGRAM
			#include "UnityCG.cginc"
            #include "../Overlays.cginc"

			#pragma target 5.0

			#pragma vertex TessellationVertex
			#pragma hull Hull
			#pragma domain Domain
			#pragma geometry Geometry
			#pragma fragment Fragment

			struct VertexData {
				float4 pos : POSITION;
				float2 texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct Interpolators {
				float4 pos : SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float4 screenPos : TEXCOORD1;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			struct TessellationControlPoint {
				float4 pos : INTERNALTESSPOS;
				float2 texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			struct TessellationFactors {
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

            Texture2D _DepthTex;
            float4 _DepthTex_TexelSize;

			SamplerState sampler_point_clamp;
			SamplerState sampler_linear_clamp;

            float _TessellationUniform;

			TessellationControlPoint TessellationVertex (VertexData v) {
				TessellationControlPoint p;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_OUTPUT(TessellationControlPoint, p);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(p);

				p.pos = v.pos;
				p.texcoord = v.texcoord;

				return p;
			}

			TessellationFactors PatchConstantFunction (
				InputPatch<TessellationControlPoint, 3> patch
			) {
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[0]);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[1]);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[2]);

				TessellationFactors f;
				f.edge[0] = _TessellationUniform;
				f.edge[1] = _TessellationUniform;
				f.edge[2] = _TessellationUniform;
				f.inside = _TessellationUniform;
				return f;
			}

			[maxvertexcount(3)]
			void Geometry (
				triangle Interpolators i[3],
				inout TriangleStream<Interpolators> stream
			) {
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i[0]);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i[1]);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i[2]);

				stream.Append(i[0]);
				stream.Append(i[1]);
				stream.Append(i[2]);
			}

			[UNITY_domain("tri")]
			[UNITY_outputcontrolpoints(3)]
			[UNITY_outputtopology("triangle_cw")]
			[UNITY_partitioning("fractional_odd")]
			[UNITY_patchconstantfunc("PatchConstantFunction")]
			TessellationControlPoint Hull (
				InputPatch<TessellationControlPoint, 3> patch,
				uint id : SV_OutputControlPointID
			) {
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[id]);
				return patch[id];
			}

			float _CameraNear;
			float _CameraFar;

			Interpolators Vertex (TessellationControlPoint v) {
				Interpolators o;
				UNITY_INITIALIZE_OUTPUT(Interpolators, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.texcoord = v.texcoord;

                float2 uv = v.texcoord.xy;
                float3 ts = float3 (_DepthTex_TexelSize.xy, 0);

			    float z = _DepthTex.SampleLevel(sampler_point_clamp, uv, 0).r;

                float3 tsOffset = ts * 5;
                float zr = _DepthTex.SampleLevel(sampler_point_clamp, uv + tsOffset.xz, 0).r;
                float zl = _DepthTex.SampleLevel(sampler_point_clamp, uv - tsOffset.xz, 0).r;
                float zu = _DepthTex.SampleLevel(sampler_point_clamp, uv + tsOffset.zy, 0).r;
                float zd = _DepthTex.SampleLevel(sampler_point_clamp, uv - tsOffset.zy, 0).r;

				float maxZ = max5(z,zr,zl,zu,zd);

				//if(z == 0)
					z = maxZ;

                if(z == 0)
                {
                    o.pos.z = 1.0/0;
                    return o;
                }

				#if UNITY_REVERSED_Z 
				float4 _CZBufferParams = float4(0,0,(-1+_CameraFar/_CameraNear)/_CameraFar,1/_CameraFar);
				#else
				float4 _CZBufferParams = float4(0,0,(1-+_CameraFar/_CameraNear)/_CameraFar,(_CameraFar/_CameraNear)/_CameraFar);
				#endif

			    float depth = LinearEyeDepthCustom(z, _CZBufferParams);

                float3 camPos = unity_ObjectToWorld._m03_m13_m23;
                float3 camForward = unity_ObjectToWorld._m02_m12_m22;
                float3 camDirection = TransformObjectToWorldDir(v.pos.xyz);

                float3 worldPos = camDirection / dot(camDirection,camForward) * depth;

                v.pos.xyz = mul(unity_WorldToObject,worldPos);

                o.pos = objectToClipPosInfinite(v.pos);

				o.screenPos = ComputeScreenPos(o.pos);

				return o;
			}

			[UNITY_domain("tri")]
			Interpolators Domain (
				TessellationFactors factors,
				OutputPatch<TessellationControlPoint, 3> patch,
				float3 barycentricCoordinates : SV_DomainLocation,
				uint pid : SV_PrimitiveID
			) {
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[0]);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[1]);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(patch[2]);

				TessellationControlPoint data;

				#define DOMAIN_INTERPOLATE(fieldName) data.fieldName = \
					patch[0].fieldName * barycentricCoordinates.x + \
					patch[1].fieldName * barycentricCoordinates.y + \
					patch[2].fieldName * barycentricCoordinates.z;

				DOMAIN_INTERPOLATE(pos)
				DOMAIN_INTERPOLATE(texcoord)

				UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(patch[0], data);

				return Vertex(data);
			}

			float4 _ShapeFillColor;
			float4 _ShapeOutlineColor;
			float _OutlineThickness;
			float _OutlineDepthMultiplier;
			float _OutlineDepthBias;
			float _OutlineDensity;
			sampler2D _PatternTex;
			float4 _PatternColor;
			float2 _PatternSize;

			fixed4 Fragment (Interpolators i) : SV_Target
			{
				float2 uv = i.texcoord.xy;
				float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float3 ts = float3 (_DepthTex_TexelSize.xy, 0);

			    float z = _DepthTex.SampleLevel(sampler_linear_clamp, uv, 0).r;

				// Discard skybox
				clip((z != 0) - 0.5);

                float3 tsOffset = ts * _OutlineThickness;
                float zr = _DepthTex.SampleLevel(sampler_linear_clamp, uv + tsOffset.xz, 0).r;
                float zl = _DepthTex.SampleLevel(sampler_linear_clamp, uv - tsOffset.xz, 0).r;
                float zu = _DepthTex.SampleLevel(sampler_linear_clamp, uv + tsOffset.zy, 0).r;
                float zd = _DepthTex.SampleLevel(sampler_linear_clamp, uv - tsOffset.zy, 0).r;

				// Outline
				float sobel = abs(zl - z) +
				abs(zr - z) +
				abs(zu - z) +
				abs(zd - z);
				sobel = pow(abs(saturate(sobel) * _OutlineDepthMultiplier), _OutlineDepthBias);
				sobel = smoothstep(0, _OutlineDensity, sobel);

				// scanlines
				float4 pattern = tex2D(_PatternTex,uv*_PatternSize) * _PatternColor;

				// Combine
				float alpha = saturate(sobel + pattern.a);

				float4 col = lerp(_ShapeFillColor, _ShapeOutlineColor, alpha) + pattern;

				return col;
			}

			ENDCG
		}
    }
    FallBack "Diffuse"
}
