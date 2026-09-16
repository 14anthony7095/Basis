Shader "Ikeiwa/HUD/Visor"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [HDR]_Color("Color",Color) = (1,1,1,1)
        [HDR]_ColorCore("Core Color",Color) = (1,1,1,1)
        _Progress ("Progress",Range(0,1)) = 1
        _HexSize ("Max Hex Size",Range(0,1)) = 1
    }
    SubShader
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
	    LOD 100
	
	    ZWrite Off
	    Blend SrcAlpha OneMinusSrcAlpha 
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float4 _Color;
            float4 _ColorCore;

            float _Progress;
            float _HexSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.color = v.color;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 masks = tex2D(_MainTex, i.uv);

                float hexProgress = min(saturate(masks.y+1 - (1-_Progress)*2),_HexSize);

                clip(hexProgress - masks.x);

                fixed4 col = lerp(_ColorCore,_Color,smoothstep(0,hexProgress,masks.x));

                col.a *= i.color.a;

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
