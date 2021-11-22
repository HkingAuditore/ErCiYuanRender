float3x3 GetTBN(float3 tangent, float3 biNormal, float3 normal)
{
    return float3x3(
        tangent.x,biNormal.x,normal.x,
        tangent.y,biNormal.y,normal.y,
        tangent.z,biNormal.z,normal.z
        );
}

float3 CalculateNormal(float3 oriNormal, float3 tangent, float3 bitagent, float2 uv, sampler2D normalMap, float intensity)
{
    float3x3 tangentTransform = float3x3(tangent,bitagent,normalize(oriNormal));
    float3 unpackNormal = UnpackNormalWithScale(tex2D(normalMap, uv),intensity);
    return normalize(mul(unpackNormal.rgb, tangentTransform));
}

float rand(float3 seed)
{
    return frac(sin(dot(seed,float3(68.656, 49.6498, 94.3219))) * 1981.1659);
}

float3x3 GetRotateMatrix(float angle, float3 axis)
{
    float c;
    float s;

    sincos(angle,s,c);

    float t = 1 - c;
    float x = axis.x;
    float y = axis.y;
    float z = axis.z;

    return float3x3(
        t*x*x+c  , t*x*y-s*z, t*x*z+s*y,
        t*x*y+s*z, t*y*y+c  , t*y*z-s*x,
        t*x*z-s*y, t*y*z+s*x, t*z*z+c
        );
}