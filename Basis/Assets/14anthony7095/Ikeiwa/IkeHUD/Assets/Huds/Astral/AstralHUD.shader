Shader "Ikeiwa/HUD/HUDs/Astral"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color("Color",Color) = (0,1,1,1)
        _PrimaryColor("Primary Accent",Color) = (0,1,1,1)
        _SecondaryColor("Secondary Accent",Color) = (1,0,0,1)
        _ShadowColor("Shadow Color",Color) = (0,0,0,0.5)
        _Opacity("Opacity",Range(0,1)) = 1

        [Header(Hidden Modules)]
        [Toggle(HIDE_COMPASS)] _HideCompass("Hide Compass", Float) = 0
        [Toggle(HIDE_CLOCK)] _HideClock("Hide Clock", Float) = 0
        [Toggle(HIDE_FPS)] _HideFPS("Hide FPS", Float) = 0
        [Toggle(HIDE_MINIMAP)] _HideMiniMap("Hide Minimap", Float) = 0
        [Toggle(HIDE_MIC)] _HideMic("Hide Microphone", Float) = 0
        [Toggle(HIDE_COORDS)] _HideCoordinates("Hide Coordinates", Float) = 0
        [Toggle(HIDE_OVERLAYS)] _HideOverlays("Hide Overlays Status", Float) = 0

        [Header(Shape)]
        _HUDOffset("Offset", Vector) = (0,0,-1,0)
        _RatioTweak("UI Ratio Tweak",Float) = 0
        _Scale("UI Scale",Float) = 1
        _ScaleRatio("UI Scale Ratio",Float) = 1
        _VRHUDOffset("VR Offset", Vector) = (0,0,-1,0)
        _VRRatioTweak("VR UI Ratio Tweak",Float) = 0
        _VRScale("VR UI Scale",Float) = 1
        _VRScaleRatio("VR UI Scale Ratio",Float) = 1
        _VRStereoSeparation("VR Stereo Separation", Float) = 0

        [Header(Radar)]
        _MapDepthTex ("Map Depth Texture", 2D) = "white" {}
        _MapDepthHighTex ("Map Depth High Texture", 2D) = "white" {}
        _PlayersTex ("Players Texture", 2D) = "white" {}
        _ZHeight( "Height", Float ) = 12
        _ZHeightHigh( "Height High", Float ) = 20
        _ZOffset("Offset", Float) = 2
        _ZOffsetHigh("Offset High", Float) = 10
        _MapSize("Map Size", Float) = 20

        [Header(Runtime Values)]
        _HUDActive("HUD Active", Range(0,1)) = 1
        _MicEnabled("Mic Enabled",Range(0,1)) = 0
        _MicLevel("Mic Level",Range(0,1)) = 0
        _OverlayActive("Overlay Is Active",Float) = 0
        _Overlay("Current Overlay",Range(0,2)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Overlay+1" }
        LOD 100
        ZTest Off
        ZWrite Off
        Cull Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature HIDE_COMPASS
            #pragma shader_feature HIDE_CLOCK
            #pragma shader_feature HIDE_FPS
            #pragma shader_feature HIDE_MINIMAP
            #pragma shader_feature HIDE_MIC
            #pragma shader_feature HIDE_COORDS
            #pragma shader_feature HIDE_OVERLAYS

            #include "UnityCG.cginc"
            #include "../../Shaders/Overlays.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 ID : TEXCOORD1;
                float2 Anchor : TEXCOORD2;
                float2 ExtraData : TEXCOORD3;
                float2 Module : TEXCOORD4;
                float4 color : COLOR;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                int2 ID : TEXCOORD1;
                float2 ExtraData : TEXCOORD2;
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _Color;
            float4 _PrimaryColor;
            float4 _SecondaryColor;
            float4 _ShadowColor;
            float _Opacity;
            float3 _HUDOffset;
            float3 _VRHUDOffset;
            float _RatioTweak;
            float _VRRatioTweak;
            float _ScaleRatio;
            float _VRScaleRatio;
            float _Scale;
            float _VRScale;
            float _VRStereoSeparation;

            //Runtime Values
            float _HUDActive;
            float _MicEnabled;
            float _MicLevel;
            float _OverlayActive;
            float _Overlay;

            //Radar
            float _ZHeight;
            float _ZHeightHigh;
            float _ZOffset;
            float _ZOffsetHigh;
            sampler2D _MapDepthTex;
            sampler2D _MapDepthHighTex;
            float4 _MapDepthHighTex_TexelSize;
            sampler2D _PlayersTex;
            float _MapSize;

            v2f vert (appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID( v );
	            UNITY_INITIALIZE_OUTPUT( v2f, o );
	            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );

                bool hidden = CheckModules(isHudHidden(), v.Module);

                if(hidden)
                {
                    o.vertex = 0;
                    o.uv = 0;
                    o.ID = 0;
                    o.ExtraData = 0;
                    o.color = 0;
                    return o;
                }

                o.uv = v.uv;
                o.ID = v.ID;
                o.ExtraData = v.ExtraData;

                o.color = lerp(_Color,_PrimaryColor,v.color.r);
                o.color = lerp(o.color,_SecondaryColor,v.color.g);
                o.color = lerp(o.color,_ShadowColor,v.color.b);
                o.color.a *= v.color.a;

                float hudProgress = remap(0,1,-5,17,_HUDActive);
                float elementAlpha = saturate(smoothstep(hudProgress+3,hudProgress-3,v.ID.x+v.ID.y));
                elementAlpha = step(Random(floor(_Time.y*50)), elementAlpha);

                o.color.a *= elementAlpha;

                float3 camForward = cameraCenterForward();

                float3 viewForward = normalize(float3(camForward.xz,0));
                float viewDir = atan2(dot(cross(viewForward,float3(0,1,0)), float3(0,0,1)),dot(viewForward,float3(0,1,0)));

                int ID = o.ID.x;
                int subID = o.ID.y;

                if(ID == ID_COMPASS)
                {
                    o.uv.x += (viewDir/TwoPI);
                }
                else if(ID == ID_TIME)
                {
                    uint minutes = _Time.y / 60;
                    uint hours = _Time.y / 3600;

				    uint m1 = minutes % 10;
				    uint m10 = minutes / 10 % 6;
				    uint h1 = hours % 10;
				    uint h10 = hours / 10 % 10;

                    float offset = m1;
                    if(subID == 1) offset = m10;
                    else if(subID == 2) offset = h1;
                    else if(subID == 3) offset = h10;

                    o.uv.x += 0.1 * offset;
                }
                else if(ID == ID_OVERLAY) 
                { 
                    _Overlay = max(1,_Overlay);

                    float3 offset = v.tangent.yxz * 0.05f;
                    offset += v.normal * 0.05f;

                    float overlayMask = saturate(1-abs(_Overlay - (subID)));

                    v.vertex.xyz += offset * (subID-_Overlay) + (v.normal * (1-overlayMask) * 0.025f);
                }
                else if(ID == ID_FPS)
                {
                    float fpsPower = pow(10,subID);
                    int fpsDigit = (abs(unity_DeltaTime.w) / fpsPower) % 10;
                    o.uv.x += fpsDigit * 0.1f;
                }
                else if(ID == ID_MINIMAP)
                {
                    o.ExtraData = o.uv;
                    o.uv = rotateUV(o.uv,viewDir);
                }
                else if(ID == ID_CARDINAL)
                {
                    float3 right = v.tangent;
                    float3 up = normalize(cross(v.tangent,v.normal))*0.85f;

                    float viewAngle = viewDir - subID*HalfPI + HalfPI;

                    float cos_angle = cos(viewAngle);
                    float abs_cos_angle = abs(cos_angle);
                    float sin_angle = sin(viewAngle);
                    float abs_sin_angle = abs(sin(sin_angle));

                    float magnitude = 1/abs_sin_angle;

                    if (abs_sin_angle <= abs_cos_angle)
                    {
                        magnitude = 1/abs_cos_angle;
                    }

                    float3 cardDir = right * (cos_angle*magnitude) + up * (sin_angle*magnitude);

                    v.vertex.xyz += cardDir*0.065f;
                }
                else if(ID == ID_MIC)
                {
                    o.color.a *= lerp(0.25,1,_MicEnabled);
                    v.vertex.xyz -= v.normal * (1-_MicEnabled)*0.025;
                }
                else if(ID >= ID_COORDX && ID <= ID_COORDZ) 
                { 
                    int coord = ObjectWorldPivot().x;

                    if(ID == ID_COORDY)
                        coord = ObjectWorldPivot().y;
                    else if(ID == ID_COORDZ)
                        coord = ObjectWorldPivot().z;

                    if(subID == SUBID_COORD_NEG && coord > 0)
                    {
                        o.color.a = 0;
                    }
                    else
                    {
                        float coordPower = pow(10,subID);
                        int coordDigit = (abs(coord) / coordPower) % 10;
                        o.uv.x += coordDigit * 0.1f;
                    }
                    
                }

                v.Anchor.y = -v.Anchor.y;

                bool isvr = isVR();

                float ratioTweak = isvr ? _VRRatioTweak : _RatioTweak;
                float ratio = (_ScreenParams.x / _ScreenParams.y - 1) / 2 + ratioTweak;

                v.vertex.xy += v.Anchor.xy/2;
                v.vertex.xyz *= isvr ? _VRScaleRatio : _ScaleRatio;
                v.vertex.xy -= v.Anchor.xy/2;

                v.vertex.x -= v.Anchor.x * ratio;

                v.vertex.xyz *= isvr ? _VRScale : _Scale;

                float3 hudOffset = _HUDOffset;

                if(isvr){
                    hudOffset = _VRHUDOffset;
                    float stereoOffset = isRightEye() ? -_VRStereoSeparation : _VRStereoSeparation;
                    hudOffset.x += stereoOffset;
                }
                hudOffset.xy *= abs(_VRHUDOffset.z);

                v.vertex.xyz += hudOffset;
                v.vertex.xz *= -1;

                unity_ObjectToWorld = cameraCenterToWorld();

                o.vertex = UnityObjectToClipPos(v.vertex);

                PixelShift(o.vertex, hudOffset.z);

                //o.vertex = mul(UNITY_MATRIX_P, v.vertex);

                return o;
            }

            float FitHeight(float depth, float camFar, float offset)
            {
                return depth * camFar - offset;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( i );

                float2 uv = i.uv;
                float2 ExtraData = i.ExtraData;

                int ID = i.ID.x;
                int subID = i.ID.y;

                fixed4 masks = tex2Dlod(_MainTex, float4(uv,0,0));

                float4 color = i.color;
                float alpha = masks.r;

                //Components
                float radarMask = saturate(i.color.r + i.color.g + i.color.b - 2);

                if(subID == SUBID_BACKGROUND)
                {
                    alpha = masks.g;
                }
                else if(ID == ID_MIC)
                {
                    if(subID == SUBID_MIC_VOL)
                    {
                        alpha = step(ExtraData.y,_MicLevel);
                    }
                }
                else if (ID == ID_OVERLAY) 
                { 
                    float overlayMask = saturate(1-abs(_Overlay - (subID))) * _OverlayActive;

                    alpha = lerp(0.5 * masks.r,1 - masks.r,overlayMask);
                }
                else if (ID == ID_CARDINAL) 
                { 
                    ExtraData -= 0.5f;
                    float cardMask = IsWithinUnitSquare(abs(ExtraData) * 24);

                    float cardinalSymbol = tex2Dlod(_MainTex, float4(uv,0,0)) * cardMask;

                    alpha = cardinalSymbol;
                }
                else if (ID == ID_MINIMAP)
                {
                    // Sample Height maps
                    float z = FitHeight(tex2D(_MapDepthTex,ExtraData), _ZHeight, _ZOffsetHigh);
		            float zHigh = FitHeight(tex2D(_MapDepthHighTex,ExtraData), _ZHeightHigh, _ZOffsetHigh);
		            float zPlayers = tex2D(_PlayersTex,ExtraData);

                    float height = zHigh;

                    // Ceilling Check
                    float2 hiddenOffset = _MapDepthHighTex_TexelSize.xy * 5;

                    float isHidden = tex2Dlod(_MapDepthHighTex, float4(float2(0.5,0.5),0,0)).r;
                    isHidden += tex2Dlod(_MapDepthHighTex, float4(float2(0.5,0.5)+float2(hiddenOffset.x,0),0,0)).r;
                    isHidden += tex2Dlod(_MapDepthHighTex, float4(float2(0.5,0.5)-float2(hiddenOffset.x,0),0,0)).r;
                    isHidden += tex2Dlod(_MapDepthHighTex, float4(float2(0.5,0.5)+float2(0,hiddenOffset.y),0,0)).r;
                    isHidden += tex2Dlod(_MapDepthHighTex, float4(float2(0.5,0.5)-float2(0,hiddenOffset.y),0,0)).r;

                    if((isHidden / 5) > 0.6f)
                    {
                        height = z;
                    }

                    // Masks
                    float heightGradient = remap(-_ZOffsetHigh,_ZOffsetHigh,0.1,0.75,height);
                    float heightWorld = height + ObjectWorldPivot().y;
                    bool playerMask = ceil(zPlayers);
                    float radarDistance = max(abs(ExtraData.x-0.5),abs(ExtraData.y-0.5))*4;
                    float radarFade = smoothstep(2,1,radarDistance)*0.75f;

                    float pulseRing = glsl_mod(radarDistance/5-_Time.y/5,1); 
                    float radarRing = smoothstep(0.9,1,pulseRing) * radarFade;
                    float playerRing = smoothstep(0.15,1,pulseRing) * radarFade * playerMask;

                    // Grid
                    float2 gridUV = uv + ObjectWorldPivot().xz/_MapSize;
                    float grid = tex2Dlod(_MainTex,float4(gridUV*3,0,4)).b;

                    // Height Lines
                    float heightLines = heightWorld + 0.7;

                    float smallLineDst = abs(glsl_mod(heightLines,1)*2-1);
                    float smallLines = smoothstep(0.98 - fwidth(smallLineDst), 0.98, smallLineDst);

                    float bigLineDst = abs(glsl_mod(heightLines/5,1)*2-1);
                    float bigLines = smoothstep(0.99 - fwidth(bigLineDst), 0.99, bigLineDst);

                    float lines = saturate(smallLines*0.25f + bigLines * 0.5f) * (1-playerMask);

                    // Player Arrow
                    float playerArrow = tex2Dlod(_MainTex,float4(i.ExtraData,0,2)).a;

                    // Final Layering
                    float mapAlpha = heightGradient + lines + grid + radarRing + playerMask + playerArrow;

                    alpha = saturate(pow(mapAlpha,2));

                    color = lerp(_Color,_PrimaryColor, saturate(playerRing + playerArrow)) * color.a;
                    color.rgb *= alpha;
                    color.a *= _Opacity;

                    return color;
                }

                color.a *= alpha * _Opacity;

                return color;
            }
            ENDCG
        }
    }
}
