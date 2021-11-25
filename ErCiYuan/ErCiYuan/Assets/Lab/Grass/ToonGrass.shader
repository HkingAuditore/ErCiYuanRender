Shader "ToonGrass/Grass"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _GrassTex ("Grass Texture", 2D) = "white" {}
        [Toggle]_IsTex("Is Tex",Float) = 0
        
        
        _AlphaClip("Alpha Clipy", Range(0, 1)) = 0.2
        _AOIntensity("AO Intensity", Range(-1, 1)) = 0.2
        
        _BaseColor("Base Color", COLOR) = (1,1,1,1)
        _AOColor("AO Color", COLOR) = (0,0,0,0)
        _ShadowColor("Shadow Color", COLOR) = (0,0,0,0)
        
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
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fwdbase 
            #pragma multi_compile_fog
            

            #include "UnityCG.cginc"
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

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 worldPos : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
                float2 globalUV : TEXCOORD3;
                SHADOW_COORDS(4)
                UNITY_FOG_COORDS(5)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D  _GrassTex;
			half4 _BaseColor;
			half4 _AOColor;
			half4 _ShadowColor;
			float4 _Grass_ST;
			half _AlphaClip;
			half _BendIntensity;
			// half _BendIntensity;
			half _BendCurve;
			half _AOIntensity;

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


            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = normalize(UnityObjectToWorldNormal(v.normal));
                o.worldPos = mul(unity_ObjectToWorld, o.pos);
                o.viewDir = normalize(UnityWorldSpaceViewDir(o.worldPos));
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                half4 tex = tex2D(_MainTex,i.uv);
                // sample the texture
                // fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                // UNITY_APPLY_FOG(i.fogCoord, col);
                half shadow = SHADOW_ATTENUATION(i);
                float3 N = i.normal;
                
                float3 L = normalize(_WorldSpaceLightPos0);
                float3 V = normalize(i.viewDir);
                
                //直射
                float NdotL = dot(N,L);
            	float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz + ShadeSH9(float4(N,1));
            	float4 shade = saturate(NdotL * shadow) * _LightColor0  + float4(ambient,1);

				// return shadow;
                half4 col = tex * lerp(_AOColor,_BaseColor,_AOIntensity)* lerp(_ShadowColor,half4(1,1,1,1),shade);
            	// col.rgb += ambient;
            	

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }

 
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
                
                half4 col = tex * lerp(_AOColor,_BaseColor,i.uv.y + _AOIntensity)* lerp(_ShadowColor,half4(1,1,1,1),shade);
                
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
            	// return 1;
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }

        
        Pass 
		{
            //此pass就是 从默认的fallBack中找到的 "LightMode" = "ShadowCaster" 产生阴影的Pass
			Tags { "LightMode" = "ShadowCaster" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing // allow instanced shadow pass for most of the shaders
			#include "UnityCG.cginc"

			struct v2f {
				V2F_SHADOW_CASTER;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert( appdata_base v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				return o;
			}

			float4 frag( v2f i ) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG

		}

        
    }
    
}