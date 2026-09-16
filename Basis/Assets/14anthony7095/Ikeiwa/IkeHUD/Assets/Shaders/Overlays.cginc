#ifndef OVERLAYS_INCLUDED
#define OVERLAYS_INCLUDED

#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y)))) 

#define PI 3.141592653589793
#define TwoPI 6.283185307179586
#define HalfPI 1.570796326794896

//invert function from https://answers.unity.com/questions/218333/shader-inversefloat4x4-function.html, thank you d4rk
float4x4 inverse(float4x4 input)
{
	#define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
	//determinant(float3x3(input._22_23_23, input._32_33_34, input._42_43_44))

	float4x4 cofactors = float4x4(
		minor(_22_23_24, _32_33_34, _42_43_44),
		-minor(_21_23_24, _31_33_34, _41_43_44),
		minor(_21_22_24, _31_32_34, _41_42_44),
		-minor(_21_22_23, _31_32_33, _41_42_43),

		-minor(_12_13_14, _32_33_34, _42_43_44),
		minor(_11_13_14, _31_33_34, _41_43_44),
		-minor(_11_12_14, _31_32_34, _41_42_44),
		minor(_11_12_13, _31_32_33, _41_42_43),

		minor(_12_13_14, _22_23_24, _42_43_44),
		-minor(_11_13_14, _21_23_24, _41_43_44),
		minor(_11_12_14, _21_22_24, _41_42_44),
		-minor(_11_12_13, _21_22_23, _41_42_43),

		-minor(_12_13_14, _22_23_24, _32_33_34),
		minor(_11_13_14, _21_23_24, _31_33_34),
		-minor(_11_12_14, _21_22_24, _31_32_34),
		minor(_11_12_13, _21_22_23, _31_32_33)
	);
	#undef minor
	return transpose(cofactors) / determinant(input);
}

inline float LinearEyeDepthCustom( float z , float4 ZBufferParams)
{
    return 1.0 / (ZBufferParams.z * z + ZBufferParams.w);
}

float4x4 GetObjectToWorldMatrix()
{
    return UNITY_MATRIX_M;
}

float4x4 worldToClip()
{
	return UNITY_MATRIX_VP;
}

float4x4 clipToWorld()
{
	return inverse(UNITY_MATRIX_VP);
}

float3 TransformObjectToWorldDir(float3 dirOS)
{
    return normalize(mul((float3x3)GetObjectToWorldMatrix(), dirOS));
}

inline int IsWithinUnitSquare(float2 uv) 
{
	return (saturate(uv.x) == uv.x) & (saturate(uv.y) == uv.y);
}

float4x4 GetInfiniteProjectionMatrix()
{
    float4x4 infinitePerspective = UNITY_MATRIX_P;
    infinitePerspective._m22 = 0.0f;
    infinitePerspective._m23 = _ProjectionParams.y;

    return infinitePerspective;
}

float4 worldToClipPosInfinite(float3 worldPos)
{
    return mul(GetInfiniteProjectionMatrix(), mul(UNITY_MATRIX_V,float4(worldPos,1.0)));
}

float4 objectToClipPosInfinite(float4 vertex)
{
    float3 worldPos = mul(unity_ObjectToWorld, float4(vertex.xyz,1.0)).xyz;

    return worldToClipPosInfinite(worldPos);
}

void FillRatio(inout float2 uv, float ratio)
{
    bool isPortrait = ratio < 1;

    float2 scaleLandscape =  float2(1.0, ratio);
    float2 scalePortrait = float2(1.0/ratio, 1.0);

    float2 scale = lerp(scaleLandscape,scalePortrait,isPortrait);

    uv -= 0.5f;
    uv /= scale;
    uv += 0.5f;
}

void FitRatio(inout float2 uv, float ratio)
{
    bool isPortrait = ratio < 1;

    float2 scaleLandscape =  float2(1.0/ratio, 1.0);
    float2 scalePortrait = float2(1.0, ratio);

    float2 scale = lerp(scaleLandscape,scalePortrait,isPortrait);

    uv -= 0.5f;
    uv /= scale;
    uv += 0.5f;
}

void BarrelDistortion(inout float2 uv, float power)
{
    uv -= 0.5;

    float theta  = atan2(uv.y, uv.x);
    float radius = length(uv);
    radius = pow(radius, power);
    uv.x = radius * cos(theta);
    uv.y = radius * sin(theta);

    uv += 0.5;
}

float horizontalFOV()
{
    float t = unity_CameraProjection._m00;
    return atan( 1.0 / t );
}

float verticalFOV()
{
    float t = unity_CameraProjection._m11;
    return atan( 1.0 / t );
}

float verticalHalfFOV()
{
    return verticalFOV() / 2.0;
}

uniform float _VRChatMirrorMode;
uniform float3 _VRChatMirrorCameraPos;
uniform float _VRChatCameraMode;
uniform uint _VRChatCameraMask;

bool isMirror() {
    return _VRChatMirrorMode > 0;
}

bool isVR() {
    #if defined(USING_STEREO_MATRICES)
    return true;
    #else
    return _VRChatMirrorMode == 1;
    #endif
}

bool isRightEye()
{
    #if defined(USING_STEREO_MATRICES)
    return unity_StereoEyeIndex == 1;
    #else
    return _VRChatMirrorMode == 1 && mul(unity_WorldToCamera, float4(_VRChatMirrorCameraPos, 1)).x < 0;
    #endif
}

#define VRC_CAMERA_MASK_UI 0x20

bool handCameraUIVisible(){
    return (_VRChatCameraMask & VRC_CAMERA_MASK_UI) == VRC_CAMERA_MASK_UI;
}

bool isRegularCamera() {
    return _VRChatCameraMode == 0;
}

bool isVRHandCamera() {
    return _VRChatCameraMode == 1;
}

bool isDesktopHandCamera() {
    return _VRChatCameraMode == 2;
}

bool isHandCamera(){
    return _VRChatCameraMode > 0 && _VRChatCameraMode < 3;
}

bool isScreenShot() {
    return _VRChatCameraMode == 3;
}

float3 cameraCenterPosition()
{
#if defined(USING_STEREO_MATRICES)
	return ( unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1] ) / 2;
#else
	return isMirror() ? _VRChatMirrorCameraPos : _WorldSpaceCameraPos.xyz;
#endif
}

float3 cameraCenterRight()
{
#if defined(USING_STEREO_MATRICES)
    return normalize((unity_StereoCameraToWorld[0]._m00_m10_m20 + unity_StereoCameraToWorld[1]._m00_m10_m20) / 2);
#else
    return normalize(unity_CameraToWorld._m00_m10_m20);
#endif
}

float3 cameraCenterUp()
{
#if defined(USING_STEREO_MATRICES)
    return normalize((unity_StereoCameraToWorld[0]._m01_m11_m21 + unity_StereoCameraToWorld[1]._m01_m11_m21) / 2);
#else
    return normalize(unity_CameraToWorld._m01_m11_m21);
#endif
}

float3 cameraCenterForward()
{
#if defined(USING_STEREO_MATRICES)
    return normalize((unity_StereoCameraToWorld[0]._m02_m12_m22 + unity_StereoCameraToWorld[1]._m02_m12_m22) / 2);
#else
    return normalize(unity_CameraToWorld._m02_m12_m22);
#endif
}

float4x4 cameraCenterToWorld()
{
    float3 camRight = cameraCenterRight();
    float3 camUp = cameraCenterUp();
    float3 camForward = cameraCenterForward();
    float3 pos = cameraCenterPosition();

    float4x4 camCenterToWorld = unity_CameraToWorld;

    camCenterToWorld._m00_m10_m20 = camRight;
    camCenterToWorld._m01_m11_m21 = camUp;
    camCenterToWorld._m02_m12_m22 = camForward;
    camCenterToWorld._m03_m13_m23 = pos;

    return camCenterToWorld;
}


// Fade Anim

sampler2D _TilesTex;
float _ProgressStart;
float _ProgressEnd;
float _TileSmoothness;
float _Distortion;

void ApplyTiles(float2 uv)
{
    float2 res = _ScreenParams.xy;

    if(isVR())
	{
		uv.x *= 2;
		uv.x += isRightEye() ? 0.1 : -0.1;
	}
    else
    {
        FillRatio(uv, res.x / res.y);
        BarrelDistortion(uv, _Distortion);
    }


    float3 masks = tex2D(_TilesTex, uv);

    float progress = saturate(smoothstep(_ProgressStart-_TileSmoothness,_ProgressStart+_TileSmoothness,masks.g) * smoothstep(_ProgressEnd+_TileSmoothness,_ProgressEnd-_TileSmoothness,masks.g));

    clip(progress - masks.x);
}

// Utils

float2 rotateUV(float2 uv, float rotation)
{
    float mid = 0.5;
    float cosAngle = cos(rotation);
    float sinAngle = sin(rotation);
    return float2(
        cosAngle * (uv.x - mid) + sinAngle * (uv.y - mid) + mid,
        cosAngle * (uv.y - mid) - sinAngle * (uv.x - mid) + mid
    );
}

inline float3 ObjectWorldPivot()
{
    return unity_ObjectToWorld._m03_m13_m23;
}

float invLerp(float from, float to, float value){
    return (value - from) / (to - from);
}

float remap(float origFrom, float origTo, float targetFrom, float targetTo, float value){
    float rel = invLerp(origFrom, origTo, value);
    return lerp(targetFrom, targetTo, rel);
}

float aaStep(float edge, float value)
{
    float halfPix = fwidth(value) / 2.0;
    float low = edge - halfPix;
    float hi  = edge + halfPix;
    return saturate((value - low) / (hi - low));
}

inline float max5(float a, float b, float c, float d, float e)
{
    return max(max(max(max(a,b),c),d),e);
}

uint Hash(uint s)
{
    s ^= 2747636419u;
    s *= 2654435769u;
    s ^= s >> 16;
    s *= 2654435769u;
    s ^= s >> 16;
    s *= 2654435769u;
    return s;
}

float Random(uint seed)
{
    return float(Hash(seed)) / 4294967295.0; // 2^32-1
}

void PixelShift(inout float4 vertex, float intensity)
{
    vertex.x += (abs(glsl_mod(_Time.x/20,1)-0.5f)-0.25f)/100 * intensity;
}

// HUD Ids

#define ID_BACKGROUND -1
#define ID_NORMAL 0
#define ID_COMPASS 1
#define ID_TIME 2
#define ID_MIC 3
#define ID_OVERLAY 4
#define ID_MINIMAP 5
#define ID_CARDINAL 6
#define ID_COORDX 7
#define ID_COORDY 8
#define ID_COORDZ 9
#define ID_FPS 10

#define SUBID_BACKGROUND -1
#define SUBID_IGNORE -2
#define SUBID_TIME_MU 0
#define SUBID_TIME_MT 1
#define SUBID_TIME_HU 2
#define SUBID_TIME_HT 3
#define SUBID_MIC_MAIN 0
#define SUBID_MIC_VOL 1
#define SUBID_OVERLAY_MAIN 0
#define SUBID_OVERLAY_WIRE 1
#define SUBID_OVERLAY_FULL 2
#define SUBID_OVERLAY_HEAT 3
#define SUBID_CARDINAL_N 0
#define SUBID_CARDINAL_E 1
#define SUBID_CARDINAL_S 2
#define SUBID_CARDINAL_W 3
#define SUBID_COORD_1 0
#define SUBID_COORD_2 1
#define SUBID_COORD_3 2
#define SUBID_COORD_4 3
#define SUBID_COORD_NEG 4
#define SUBID_FPS_UNIT 0
#define SUBID_FPS_TENS 1
#define SUBID_FPS_HUNDRED 2

#define MODULE_COMPASS 0
#define MODULE_CLOCK 1
#define MODULE_FPS 2
#define MODULE_MINIMAP 3
#define MODULE_MIC 4
#define MODULE_COORDS 5
#define MODULE_OVERLAYS 6

bool isHudHidden()
{
    return isMirror() || (isHandCamera() && !handCameraUIVisible());
}

bool CheckModules(bool hidden, int module)
{
    #if HIDE_COMPASS
    hidden = hidden || module == MODULE_COMPASS;
    #endif

    #if HIDE_CLOCK
    hidden = hidden || module == MODULE_CLOCK;
    #endif

    #if HIDE_FPS
    hidden = hidden || module == MODULE_FPS;
    #endif

    #if HIDE_MINIMAP
    hidden = hidden || module == MODULE_MINIMAP;
    #endif

    #if HIDE_MIC
    hidden = hidden || module == MODULE_MIC;
    #endif

    #if HIDE_COORDS
    hidden = hidden || module == MODULE_COORDS;
    #endif

    #if HIDE_OVERLAYS
    hidden = hidden || module == MODULE_OVERLAYS;
    #endif

    return hidden;
}

// Debug
// "PrintValue" function by P.Malin
uint DigitBin(const uint x)
{
    return x==0?480599:x==1?139810:x==2?476951:x==3?476999:x==4?350020:x==5?464711:x==6?464727:x==7?476228:x==8?481111:x==9?481095:0;
}

uint DigitPower(const uint x)
{
    return x==1?10:x==2?100:x==3?1000:x==4?10000:x==5?100000:x==6?1000000:x==7?10000000:x==8?100000000:x==9?1000000000:1;
}

float PrintValue(float2 vStringCoords, float fValue, float fMaxDigits, float fDecimalPlaces)
{
    if ((vStringCoords.y < 0.0) || (vStringCoords.y >= 1.0))
        return 0.0;

    bool bNeg = (fValue < 0.0);
    fValue = abs(fValue);

    float fLog10Value = log2(abs(fValue)) / log2(10.0);
    float fBiggestIndex = max(floor(fLog10Value), 0.0);
    float fDigitIndex = fMaxDigits - floor(vStringCoords.x);
    float fCharBin = 0.0;
    if (fDigitIndex > (-fDecimalPlaces - 1.01))
    {
        if(fDigitIndex > fBiggestIndex)
        {
            if((bNeg) && (fDigitIndex < (fBiggestIndex+1.5))) fCharBin = 1792.0;
        }
        else
        {
            if(fDigitIndex == -1.0)
            {
                if(fDecimalPlaces > 0.0) fCharBin = 2.0;
            }
            else
            {
                float fReducedRangeValue = fValue;
                if(fDigitIndex < 0.0) { fReducedRangeValue = frac( fValue ); fDigitIndex += 1.0; }
                float fDigitValue = (abs(fReducedRangeValue / (pow(10.0, fDigitIndex))));
                fCharBin = DigitBin(int(floor(fmod(fDigitValue, 10.0))));
            }
        }
    }
    return floor(fmod((fCharBin / pow(2.0, floor(frac(vStringCoords.x) * 4.0) + (floor(vStringCoords.y * 5.0) * 4.0))), 2.0));
}

float PrintValueUInt(float2 vStringCoords, uint fValue)
{
    if ((vStringCoords.y < 0.0) || (vStringCoords.y >= 1.0))
        return 0.0;

    float fLog10Value = log2(fValue) / log2(10);
    uint fBiggestIndex = max(floor(fLog10Value), 0);
    uint fDigitIndex = 10 - floor(vStringCoords.x);
    int maxDigitIndex = 10 - floor(vStringCoords.x);
    uint fCharBin = 0;

    if(fDigitIndex <= fBiggestIndex && maxDigitIndex > -1)
    {
        uint fDigitValue = fValue / DigitPower(fDigitIndex);
        fCharBin = DigitBin(fDigitValue % 10);
    }

    return floor(fmod((fCharBin / pow(2, floor(frac(vStringCoords.x) * 4) + (floor(vStringCoords.y * 5) * 4))), 2));
}

float PrintValueInt(float2 vStringCoords, int fValue)
{
    if ((vStringCoords.y < 0.0) || (vStringCoords.y >= 1.0))
        return 0.0;

    bool bNeg = (fValue < 0.0);
    fValue = abs(fValue);

    float fLog10Value = log2(fValue) / log2(10);
    uint fBiggestIndex = max(floor(fLog10Value), 0);
    uint fDigitIndex = 10 - floor(vStringCoords.x);
    int maxDigitIndex = 10 - floor(vStringCoords.x);
    uint fCharBin = 0;

    if(fDigitIndex > fBiggestIndex)
    {
        if((bNeg) && (fDigitIndex < uint(fBiggestIndex+1.5))) fCharBin = 1792;
    }
    else if(maxDigitIndex > -1)
    {
        uint fDigitValue = fValue / DigitPower(fDigitIndex);
        fCharBin = DigitBin(fDigitValue % 10);
    }

    return floor(fmod((fCharBin / pow(2, floor(frac(vStringCoords.x) * 4) + (floor(vStringCoords.y * 5) * 4))), 2));
}

#endif