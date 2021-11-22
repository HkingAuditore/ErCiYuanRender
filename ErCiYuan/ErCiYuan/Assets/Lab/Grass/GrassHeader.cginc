#include <UnityShadowLibrary.cginc>

#include "CustomTessellation.cginc"
#include "MyShaderInc.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

struct appdata
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
};

struct v2g
{
    float4 vertex : SV_POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
};

struct g2f
{
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
    float4 worldPos : TEXCOORD1;
    float3 viewDir : TEXCOORD2;
    float2 globalUV : TEXCOORD3;
    unityShadowCoord4 _ShadowCoord : TEXCOORD4;
    UNITY_FOG_COORDS(5)
};

sampler2D  _GrassTex;
half4 _BaseColor;
half4 _AOColor;
float4 _Grass_ST;
half _AlphaClip;
half _BendIntensity;
// half _BendIntensity;
half _BendCurve;

sampler2D _GrassHeightMap;
float4 _GrassHeightMap_ST;
half _MaxWidth;
half _MinWidth;
half _MaxHeight;
half _MinHeight;


sampler2D _WindDistortionMap;
float4 _WindDistortionMap_ST;
float2 _WindFrequency;
float _WindStrength;


v2g vert(appdata v)
{
    v2g o;
    o.vertex = v.vertex;
    o.uv = v.uv;
    o.normal = v.normal;
    o.tangent = v.tangent;
    return o;
}

g2f GetGrassVertexGeo(float3 pos, float2 uv, float3 normal, float2 globalUV)
{
    g2f o;
    o.vertex = UnityObjectToClipPos(pos);
    o.uv = uv;
    o.normal = normalize(UnityObjectToWorldNormal(normal));
    o.worldPos = mul(unity_ObjectToWorld, o.vertex);
    o.viewDir = normalize(UnityWorldSpaceViewDir(o.worldPos));
    o.globalUV = globalUV;
    o._ShadowCoord = ComputeScreenPos(o.vertex);
    UNITY_TRANSFER_FOG(o,o.vertex);
    #if UNITY_PASS_SHADOWCASTER
        o.vertex = UnityApplyLinearShadowBias(o.vertex);
    #endif

    return o;
}

g2f GenerateGrass(float3 pos, float width, float height, float bendIntensity, float2 uv, float2 globalUV, float3x3 transMatrix)
{
    float3 tangentPos = float3(width, bendIntensity, height); // 在这里计算offset
    
    float3 normal = normalize(float3(0,-1,bendIntensity));
    float3 localNormal = mul(transMatrix, normal);
    
    float3 localPos = pos + mul(transMatrix, tangentPos);
    return GetGrassVertexGeo(localPos, uv, localNormal, globalUV);
}


#if defined(_ISTEX_ON)
    #define GRASS_SEGMENTS 2
#else
    #define GRASS_SEGMENTS 4
#endif

[maxvertexcount(GRASS_SEGMENTS * 2 + 1)]
void geom(triangle v2g IN[3], inout TriangleStream<g2f> triStream)
{
    g2f o;

    float3 centerPos = IN[0].vertex;
    // 用TBN矩阵，把顶点转到物体空间，让草沿着法线生长
    float3x3 tbn = GetTBN(IN[0].tangent, cross(IN[0].normal, IN[0].tangent) * IN[0].tangent.w, IN[0].normal);

    //风
    float2 WindUV = centerPos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
    float2 windSample = (tex2Dlod(_WindDistortionMap, float4(WindUV, 0, 0)).xy) * _WindStrength * .25;
    float3x3 windRotationXMatrix = GetRotateMatrix(UNITY_PI * windSample.x, float3(1, 0, 0));
    float3x3 windRotationYMatrix = GetRotateMatrix(UNITY_PI * windSample.y, float3(0, 0, 1));
    float3x3 windRotationMatrix = mul(windRotationXMatrix,windRotationYMatrix);

    //高度
    float2 HeightUV = centerPos.xz * _GrassHeightMap_ST.xy + _GrassHeightMap_ST.zw;
    float2 heightSample = (tex2Dlod(_GrassHeightMap, float4(HeightUV, 0, 0)).xy);

    //旋转
    float3x3 rotateMatrix = GetRotateMatrix(rand(centerPos) * UNITY_TWO_PI, float3(0, 0, 1));
    //弯曲
    float3x3 bendMatrix = GetRotateMatrix(rand(centerPos.zzx) * _BendIntensity  * UNITY_PI * .5, float3(-1, 0, 0));
    float3x3 transformBodyMatrix = mul(mul(mul(tbn, rotateMatrix), bendMatrix),windRotationMatrix);
    float3x3 transformBottomMatrix = mul(tbn, rotateMatrix); //底部的旋转矩阵

    float height = lerp(_MaxHeight, _MinHeight, (rand(centerPos.zyx) * 2 - 1) )* (heightSample +.4);
    float width = lerp(_MaxWidth, _MinWidth, (rand(centerPos.xzy) * 2 - 1));
    //草上移前倾
    float bendIntensity = rand(centerPos.yyz) * _BendIntensity;

    for (int i = 0; i < GRASS_SEGMENTS; i++)
    {
        // 细分小节
        float step = i / (float)GRASS_SEGMENTS;
        #if defined(_ISTEX_ON)
            float segmentHeight = height * step;
            float segmentWidth = width;
        #else
            float segmentHeight = height * step;
            float segmentWidth = width * (1 - step);
        #endif
        float segmentBendIntensity = pow(step, _BendCurve) * bendIntensity;
        // 判断是否为底部
        float3x3 matrixApplied = i == 0 ? transformBottomMatrix : transformBodyMatrix;
        triStream.Append(GenerateGrass(centerPos, segmentWidth, segmentHeight, segmentBendIntensity, float2(0, step),centerPos.xz,
                                       matrixApplied));
        triStream.Append(GenerateGrass(centerPos, -segmentWidth, segmentHeight, segmentBendIntensity, float2(1, step),centerPos.xz,
                                       matrixApplied));
    }

    #if defined(_ISTEX_ON)
    #else
        triStream.Append(GenerateGrass(centerPos, 0, height, bendIntensity, float2(.5, 1),centerPos.xz, transformBodyMatrix)); //法线的上在z方向
    #endif
    // triStream.Append(GenerateGrass(centerPos, -width, height, bendIntensity, float2(0, 1), transformBodyMatrix)); //法线的上在z方向
    // triStream.Append(GenerateGrass(centerPos, width, height, bendIntensity, float2(1, 1), transformBodyMatrix)); //法线的上在z方向


    // triStream.RestartStrip();
}
