Shader "Ikeiwa/HUD/Ping"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _MaxAngle("Max Angle",Range(0,1)) = 0.75
        _MaxAngleVR("Max Angle VR",Range(0,1)) = 0.6
        _Size("Size",Float) = 1
        [HideInInspector] _Scale("Scale",Float) = 1
        [HideInInspector] _Opacity("Opacity",Range(0,1)) = 1
    }
    SubShader
    {
        Tags {"Queue"="Overlay" "IgnoreProjector"="True" "RenderType"="Transparent"}
	    LOD 100
	
        Cull Off
	    ZWrite Off
        ZTest Always
	    Blend SrcAlpha OneMinusSrcAlpha 

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "../../../Shaders/Overlays.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            half4 _Color;
            float _MaxAngle;
            float _MaxAngleVR;
            float _Size, _Scale, _Opacity;

            #define M_PI 3.14159265359

		    float3 RotateAboutAxis(float3 In, float3 Axis, float Rotation)
            {
                float s = sin(Rotation);
                float c = cos(Rotation);
                float one_minus_c = 1.0 - c;

                Axis = normalize(Axis);
                float3x3 rot_mat = 
                {   one_minus_c * Axis.x * Axis.x + c, one_minus_c * Axis.x * Axis.y - Axis.z * s, one_minus_c * Axis.z * Axis.x + Axis.y * s,
                    one_minus_c * Axis.x * Axis.y + Axis.z * s, one_minus_c * Axis.y * Axis.y + c, one_minus_c * Axis.y * Axis.z - Axis.x * s,
                    one_minus_c * Axis.z * Axis.x - Axis.y * s, one_minus_c * Axis.y * Axis.z + Axis.x * s, one_minus_c * Axis.z * Axis.z + c
                };
                return mul(rot_mat,  In);
            }

            float angleBetween(float3 target, float3 origin) {
	            return acos(dot(target, origin));
            }

            v2f vert (appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID( v );
                UNITY_INITIALIZE_OUTPUT( v2f, o );
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );

                if(isMirror()){
                    o.vertex = 0;
                    o.uv = 0;
                    return o;
                }

                float3 objectPivot = ObjectWorldPivot();
                float3 cameraPos = cameraCenterPosition();
                float3 cameraForward = cameraCenterForward();
                float3 cameraRight = cameraCenterRight();

                float3 pingDir = objectPivot - cameraPos;
                float dist = length(pingDir);
                pingDir = normalize(pingDir);
                float angle = angleBetween(cameraForward,pingDir);
                float3 pingPlane = normalize(cross(cameraForward, pingDir));

                // Calculate angle to recenter ping
                _MaxAngle = isVR() ? _MaxAngleVR : _MaxAngle;
                float maxAngleV = verticalFOV() * _MaxAngle;
                float maxAngleH = horizontalFOV() * _MaxAngle;

                float isVertical = abs(dot(pingPlane,cameraRight));
                float maxAngle = lerp(maxAngleH,maxAngleV,isVertical);

                float angleDiff = -max(angle - maxAngle,0);

                pingDir = normalize(RotateAboutAxis(pingDir, pingPlane, angleDiff));

                objectPivot = cameraPos + pingDir * dist;

                // Billboard
                float3 forward = pingDir;
                float3 up = float3(0.0,1.0,0.0);
                float3 right = normalize(cross(up, forward));
                up = -normalize(cross(right, forward));

                float3x3 billboardRotation = float3x3(right, up, forward);

                v.vertex.xyz *= dist * _Size * _Scale;

                float3 worldPos = mul(v.vertex.xyz, billboardRotation) + objectPivot;
                
                o.vertex = worldToClipPosInfinite(worldPos);

                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( i );

                fixed4 col = tex2D(_MainTex, i.uv) * _Color;
                col.a *= _Opacity;
                return col;
            }
            ENDCG
        }
    }
}
