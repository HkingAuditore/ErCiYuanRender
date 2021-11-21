Shader "Unlit/YuanShen"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RampTex ("Ramp Texture", 2D) = "white" {}
        _ShadowAttWeight("Shadow AttWeight",Range(0,1)) = .5
        _Threshold("Threshold",Range(0,1)) = .5
        _OutlineStrength("Outline Strength",Range(0,1)) = .5
    	_OutlineTex("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
		
	    Pass{
            Cull Front
	        Offset 20,20
	        
	        CGPROGRAM
	        #pragma vertex vert
			#pragma fragment frag
            #include "UnityCG.cginc"

	        sampler2D _OutlineTex;
            float4 _OutlineTex_ST;
	        fixed _OutlineStrength;


            struct v2g
            {
                float4 pos : SV_POSITION;
            	float2 uv : TEXCOORD0;
            };

	        v2g vert(appdata_full v)
	        {
	            v2g o;
	            o.pos = UnityObjectToClipPos(v.vertex);
	        	float3 dir = abs(v.tangent.xyz) > abs(v.normal.xyz) ? v.tangent.xyz : v.normal.xyz;
	            half3 normalView = mul((float3x3)UNITY_MATRIX_MV, dir);
	        	
	        	float2 ndcNormal = normalize(TransformViewToProjection(normalView.xy)) * o.pos.w;//将法线变换到NDC空间
	        	float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));//将近裁剪面右上角位置的顶点变换到观察空间
				float aspect = abs(nearUpperRight.y / nearUpperRight.x);//求得屏幕宽高比
	        	ndcNormal.x *= aspect;
	        	o.pos.xy += ndcNormal * _OutlineStrength * .01;
	        	o.uv = TRANSFORM_TEX(v.texcoord, _OutlineTex);
	        	return o;
	        }

	        fixed4 frag(v2g i) : SV_Target{
	        	fixed4 col = tex2D(_OutlineTex, i.uv);
				return col;
	        }
	        
	        ENDCG
	        

        }

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
	        	float3 normal : NORMAL;
	        	float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2g
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            	float3 worldNormal : TEXCOORD1;
            	float3 worldLight : TEXCOORD2;
            	float3 viewDir: TEXCOORD3;
            };

            sampler2D _MainTex;
            sampler2D _RampTex;
            float4 _MainTex_ST;
            fixed _ShadowAttWeight;
            fixed _Threshold;

            v2g vert (appdata v)
            {
                v2g o;
                o.vertex = UnityObjectToClipPos(v.vertex);
            	o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
            
				o.worldLight = normalize(_WorldSpaceLightPos0.xyz);
            	o.viewDir = normalize(_WorldSpaceCameraPos.xyz - mul(unity_ObjectToWorld,v.vertex).xyz);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            half lighting(half3 normal, half3 lightDir, half3 viewDir, half atten)
            {
            	float3 reflectDir = reflect(-viewDir, normal);
				float3 N = normalize(normal);
            	half NdotL = dot(N,lightDir);
            	half halfLambert = NdotL * .5 + .5;
            	
            	half3 HDir = normalize(lightDir + viewDir);
				half NdotH = pow(dot(N, HDir),2) + _ShadowAttWeight * (atten - 1);
            	half SpecularSize = pow(NdotH, .5);
            	
				half VdotN = dot(N, viewDir);
				half VdotL = dot(viewDir, lightDir);
				half VdotH = dot(viewDir, HDir) + _ShadowAttWeight * 2 * (atten - 1);
			
		
				
            	return max(halfLambert,SpecularSize)  ;
            }
            
            fixed rim(half3 normal, half3 lightDir, half3 viewDir, half rimPower)
            {
            	float rim = 1 - max(0, dot(viewDir, normalize(normal)));
            	fixed rimColor = rimPower * pow(rim, 1 / rimPower);
            	return rimColor;
            }

            fixed4 frag (v2g i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed r = 1 - rim(i.worldNormal,i.worldLight,i.viewDir,0.2);
            	half light = lighting(i.worldNormal,i.worldLight,i.viewDir,.8);
            	fixed4 rimLight = tex2D(_RampTex, float2(r,0));
            	rimLight.a = r * .2;
            	fixed4 ramp = tex2D(_RampTex, float2(light,0));
            	col = pow(ramp,.5) * col;
				col = col * (1-rimLight.a) + rimLight * (rimLight.a); 
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
