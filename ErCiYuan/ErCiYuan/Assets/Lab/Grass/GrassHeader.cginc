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
    unityShadowCoord4 _ShadowCoord : TEXCOORD1;
    // UNITY_FOG_COORDS(1)
};

sampler2D _MainTex;
half4 _BaseColor;
half4 _HeightShadowColor;
float4 _MainTex_ST;

half _BendIntensity;
// half _BendIntensity;
half _BendCurve;

half _MaxWidth;
half _MinWidth;
half _MaxHeight;
half _MinHeight;

v2g vert(appdata v)
{
    v2g o;
    o.vertex = v.vertex;
    o.uv = v.uv;
    o.normal = v.normal;
    o.tangent = v.tangent;
    return o;
}

g2f GetGrassVertexGeo(float3 pos, float2 uv, float3 normal)
{
    g2f o;
    o.vertex = UnityObjectToClipPos(pos);
    o.uv = uv;
    o.normal = UnityObjectToWorldNormal(normal);
    o._ShadowCoord = ComputeScreenPos(o.vertex);
    #if UNITY_PASS_SHADOWCASTER
        o.vertex = UnityApplyLinearShadowBias(o.vertex);
    #endif

    return o;
}

g2f GenerateGrass(float3 pos, float width, float height, float bendIntensity, float2 uv, float3x3 transMatrix)
{
    float3 tangentPos = float3(width, bendIntensity, height); // 在这里计算offset

    float3 tangentNormal = float3(0,-1,0);
    float3 localNormal = mul(transMatrix, tangentNormal);
    
    float3 localPos = pos + mul(transMatrix, tangentPos);
    return GetGrassVertexGeo(localPos, uv, localNormal);
}


#define GRASS_SEGMENTS 3

[maxvertexcount(GRASS_SEGMENTS * 2 + 1)]
void geom(triangle v2g IN[3], inout TriangleStream<g2f> triStream)
{
    g2f o;

    float3 centerPos = IN[0].vertex;
    // 用TBN矩阵，把顶点转到物体空间，让草沿着法线生长
    float3x3 tbn = GetTBN(IN[0].tangent, cross(IN[0].normal, IN[0].tangent) * IN[0].tangent.w, IN[0].normal);

    //旋转
    float3x3 rotateMatrix = GetRotateMatrix(rand(centerPos) * UNITY_TWO_PI, float3(0, 0, 1));
    //弯曲
    float3x3 bendMatrix = GetRotateMatrix(rand(centerPos.zzx) * _BendIntensity * UNITY_PI * .5, float3(-1, 0, 0));
    float3x3 transformBodyMatrix = mul(mul(tbn, rotateMatrix), bendMatrix);
    float3x3 transformBottomMatrix = mul(tbn, rotateMatrix); //底部的旋转矩阵

    float height = lerp(_MaxHeight, _MinHeight, (rand(centerPos.zyx) * 2 - 1));
    float width = lerp(_MaxWidth, _MinWidth, (rand(centerPos.xzy) * 2 - 1));
    //草上移前倾
    float bendIntensity = rand(centerPos.yyz) * _BendIntensity;

    for (int i = 0; i < GRASS_SEGMENTS; i++)
    {
        // 细分小节
        float step = i / (float)GRASS_SEGMENTS;
        float segmentHeight = height * step;
        float segmentWidth = width * (1 - step);
        float segmentBendIntensity = pow(step, _BendCurve) * bendIntensity;
        // 判断是否为底部
        float3x3 matrixApplied = i == 0 ? transformBottomMatrix : transformBodyMatrix;
        triStream.Append(GenerateGrass(centerPos, segmentWidth, segmentHeight, segmentBendIntensity, float2(0, step),
                                       matrixApplied));
        triStream.Append(GenerateGrass(centerPos, -segmentWidth, segmentHeight, segmentBendIntensity, float2(1, step),
                                       matrixApplied));
    }

    triStream.Append(GenerateGrass(centerPos, 0, height, bendIntensity, float2(.5, 1), transformBodyMatrix)); //法线的上在z方向


    // triStream.RestartStrip();
}
