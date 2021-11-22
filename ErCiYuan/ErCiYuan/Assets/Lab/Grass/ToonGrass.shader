Shader "ToonGrass/Grass"
{
    Properties
    {
        _GrassTex ("Grass Texture", 2D) = "white" {}
        [Toggle]_IsTex("Is Tex",Float) = 0
        
        
        _AlphaClip("Alpha Clipy", Range(0, 1)) = 0.2
        
        _BaseColor("Base Color", COLOR) = (1,1,1,1)
        _AOColor("AO Color", COLOR) = (0,0,0,0)
        
        _BendIntensity("Bend Intensity", Range(0, 2)) = 0.2
//        _BendIntensity("Bend Forward Amount", Float) = 0.38
        _BendCurve("Bend Curvature Amount", Range(1, 4)) = 2
        
        _TessellationUniform("Tessellation Uniform", Range(0, 64)) = 1
        
        _GrassHeightMap("Grass Height Map", 2D) = "white" {}
        _MaxWidth("Max Width", Float) = 0.1
        _MinWidth("Min Width", Float) = 0.2
        _MaxHeight("Max Height", Float) = 0.2
        _MinHeight("Min Height", Float) = 0.5
        
        _WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        _WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
        _WindStrength("Wind Strength", Range(0, 1)) = .5
        
        [Toggle]_LowCostMode("Low Cost Mode",Float) = 0
    }
    SubShader
    {
        Tags { "Queue"="Geometry" "RenderType"="Opaque" }
        
        LOD 100
 
        Pass
        {
            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma geometry geom
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma multi_compile_fwdbase
            #pragma shader_feature _ISTEX_ON
            // #pragma shader_feature _LowCostMode_ON _LowCostMode_OFF
            // #define _LowCostMode_OFF
            
 
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "GrassHeader.cginc"

            float SimpleTransmission(float3 N,float3 L,float3 V,float TransLerp,float TransExp,float TransIntensity,float ThicknessFade)
            {
                float3 fakeN = -normalize(lerp(-N,L,TransLerp));
                float trans = TransIntensity * pow( saturate( dot(fakeN,V)),TransExp);
                return trans*ThicknessFade;
            }

            float3 GetFakeSSS(
                      float3 lightDir,  float3 viewDir,float3 normal,half3 ambient,
                      half thickness, half intensity,half shade,half distortion)
            {
                float3 frontH = normalize(-lightDir + normal * (distortion));
                float frontVdotH = pow(saturate(dot(viewDir,-frontH)),1.2) * intensity;
                
                float3 backH = normalize(lightDir + normal * (distortion));
                float backVdotH = pow(saturate(dot(viewDir,-backH)),1.2* thickness) * intensity;
                

                float3 I = saturate(shade * (frontVdotH+backVdotH + ambient));
                
                
                return I;
            }



 
            fixed4 frag (g2f i, half facing : VFACE) : SV_Target
            {
                half4 tex = tex2D(_GrassTex,i.uv);
                clip(tex.a-_AlphaClip);
                // sample the texture
                // fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                // UNITY_APPLY_FOG(i.fogCoord, col);
                half shadow = SHADOW_ATTENUATION(i);
                float3 N = facing > 0 ? i.normal : -i.normal;
                
                float3 L = normalize(_WorldSpaceLightPos0);
                float3 V = normalize(i.viewDir);
                
                //直射
                float NdotL = dot(N,L);
                //透射
                float transmission = SimpleTransmission(N,L,V,.8,5,.3,1.5);
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz + ShadeSH9(float4(N,1));
                float3 sss = GetFakeSSS(L,V,N,ambient,.2,.8,shadow,.5);
                // return half4(sss,1);
                float4 shade = saturate(NdotL * shadow  + transmission * (shadow + .1) + sss.x) * _LightColor0  + float4(ambient,1);

                // return shadow;
                
                half4 col = tex * lerp(_AOColor,_BaseColor,i.uv.y)* saturate(shade*.5+.5);
                
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
        
        Pass
        {
            Tags{"LightMode" = "ShadowCaster"}
            CGPROGRAM
            
            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma geometry geom
            #pragma fragment frag
            // make fog work
            #pragma target 4.6
            #pragma multi_compile_shadowcaster
            #pragma shader_feature _ISTEX_ON
            #pragma shader_feature _LowCostMode_ON _LowCostMode_OFF
 
            #include "UnityCG.cginc"
            #include "GrassHeader.cginc"

            
 
            fixed4 frag (g2f i) : SV_Target
            {
                half4 tex = tex2D(_GrassTex,i.uv);
                clip(tex.a-_AlphaClip);
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
}