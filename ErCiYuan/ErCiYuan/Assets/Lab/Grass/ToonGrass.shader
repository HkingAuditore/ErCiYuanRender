Shader "ToonGrass/Grass"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        
        _BaseColor("Base Color", COLOR) = (1,1,1,1)
        _HeightShadowColor("Height Shadow Color", COLOR) = (0,0,0,0)
        
        _BendIntensity("Bend Intensity", Range(0, 1)) = 0.2
//        _BendIntensity("Bend Forward Amount", Float) = 0.38
        _BendCurve("Bend Curvature Amount", Range(1, 4)) = 2
        
        _TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1
        
        _MaxWidth("Max Width", Float) = 0.1
        _MinWidth("Min Width", Float) = 0.2
        _MaxHeight("Max Height", Float) = 0.2
        _MinHeight("Min Height", Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
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
            
 
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "GrassHeader.cginc"
 
            
 
            fixed4 frag (g2f i, half facing : VFACE) : SV_Target
            {
                // sample the texture
                // fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                // UNITY_APPLY_FOG(i.fogCoord, col);
                half shade = SHADOW_ATTENUATION(i);
                float3 N = facing > 0 ? i.normal : -i.normal;
                return lerp(_HeightShadowColor,_BaseColor,i.uv.y) * shade;
            }
            ENDCG
        }
        
        Pass{
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
 
            #include "UnityCG.cginc"
            #include "GrassHeader.cginc"
            
 
            fixed4 frag (g2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
}