Shader "Hidden/Universal Render Pipeline/StencilDeferred"
{
    Properties {
        _StencilRef ("StencilRef", Int) = 0
        _StencilReadMask ("StencilReadMask", Int) = 0
        _StencilWriteMask ("StencilWriteMask", Int) = 0

        _LitPunctualStencilRef ("LitPunctualStencilWriteMask", Int) = 0
        _LitPunctualStencilReadMask ("LitPunctualStencilReadMask", Int) = 0
        _LitPunctualStencilWriteMask ("LitPunctualStencilWriteMask", Int) = 0

        _SimpleLitPunctualStencilRef ("SimpleLitPunctualStencilWriteMask", Int) = 0
        _SimpleLitPunctualStencilReadMask ("SimpleLitPunctualStencilReadMask", Int) = 0
        _SimpleLitPunctualStencilWriteMask ("SimpleLitPunctualStencilWriteMask", Int) = 0

        _LitDirStencilRef ("LitDirStencilRef", Int) = 0
        _LitDirStencilReadMask ("LitDirStencilReadMask", Int) = 0
        _LitDirStencilWriteMask ("LitDirStencilWriteMask", Int) = 0

        _SimpleLitDirStencilRef ("SimpleLitDirStencilRef", Int) = 0
        _SimpleLitDirStencilReadMask ("SimpleLitDirStencilReadMask", Int) = 0
        _SimpleLitDirStencilWriteMask ("SimpleLitDirStencilWriteMask", Int) = 0

        _ClearStencilRef ("ClearStencilRef", Int) = 0
        _ClearStencilReadMask ("ClearStencilReadMask", Int) = 0
        _ClearStencilWriteMask ("ClearStencilWriteMask", Int) = 0
    }

    HLSLINCLUDE

    // _ADDITIONAL_LIGHT_SHADOWS is shader keyword globally enabled for a range of render-passes.
    // When rendering deferred lights, we need to set/unset this flag dynamically for each deferred
    // light, however there is no way to restore the value of the keyword, whch is needed by the
    // forward transparent pass. The workaround is to use a new shader keyword
    // _DEFERRED_ADDITIONAL_LIGHT_SHADOWS to set _ADDITIONAL_LIGHT_SHADOWS as a #define, so that
    // the "state" of the keyword itself is unchanged.
    #ifdef _DEFERRED_ADDITIONAL_LIGHT_SHADOWS
    #define _ADDITIONAL_LIGHT_SHADOWS 1
    #endif

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/Shaders/Utils/Deferred.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

    
    #if defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL) // #if defined(PLATFORM_SUPPORTS_NATIVE_RENDERPASS)
    #if defined(UNITY_COMPILER_DXC)

        //Subpass inputs are disallowed in non-fragment shader stages with DXC so we need some dummy value to use in the fragment function while it's not being compiled
    #if defined(SHADER_STAGE_FRAGMENT)
    #define UNITY_DXC_SUBPASS_INPUT_TYPE_INDEX(type, idx) [[vk::input_attachment_index(idx)]] SubpassInput<type##4> hlslcc_fbinput_##idx
    #define UNITY_DXC_SUBPASS_INPUT_TYPE_INDEX_MS(type, idx) [[vk::input_attachment_index(idx)]] SubpassInputMS<type##4> hlslcc_fbinput_##idx
    #else
        //declaring dummy resources here so that non-fragment shader stage automatic bindings wouldn't diverge from the fragment shader (important for vulkan)
    #define UNITY_DXC_SUBPASS_INPUT_TYPE_INDEX(type, idx) Texture2D dxc_dummy_fbinput_resource##idx; static type DXC_DummySubpassVariable##idx = type(0).xxxx;
    #define UNITY_DXC_SUBPASS_INPUT_TYPE_INDEX_MS(type, idx) Texture2D dxc_dummy_fbinput_resource##idx; static type DXC_DummySubpassVariable##idx = type(0).xxxx
    #endif
    // Renderpass inputs: Vulkan/Metal subpass input
    #define FRAMEBUFFER_INPUT_FLOAT(idx) UNITY_DXC_SUBPASS_INPUT_TYPE_INDEX(float, idx)
    #define FRAMEBUFFER_INPUT_FLOAT_MS(idx) UNITY_DXC_SUBPASS_INPUT_TYPE_INDEX_MS(float, idx)
    // For halfs
    #define FRAMEBUFFER_INPUT_HALF(idx) UNITY_DXC_SUBPASS_INPUT_TYPE_INDEX(half, idx)
    #define FRAMEBUFFER_INPUT_HALF_MS(idx) UNITY_DXC_SUBPASS_INPUT_TYPE_INDEX_MS(half, idx)
    // For ints
    #define FRAMEBUFFER_INPUT_INT(idx) UNITY_DXC_SUBPASS_INPUT_TYPE_INDEX(int, idx)
    #define FRAMEBUFFER_INPUT_INT_MS(idx) UNITY_DXC_SUBPASS_INPUT_TYPE_INDEX_MS(int, idx)
    // For uints
    #define FRAMEBUFFER_INPUT_UINT(idx) UNITY_DXC_SUBPASS_INPUT_TYPE_INDEX(uint, idx)
    #define FRAMEBUFFER_INPUT_UINT_MS(idx) UNITY_DXC_SUBPASS_INPUT_TYPE_INDEX_MS(uint, idx)

    #if defined(SHADER_STAGE_FRAGMENT)
    #define LOAD_FRAMEBUFFER_INPUT(idx, v2fname) hlslcc_fbinput_##idx.SubpassLoad()
    #define LOAD_FRAMEBUFFER_INPUT_MS(idx, sampleIdx, v2fname) hlslcc_fbinput_##idx.SubpassLoad(sampleIdx)
    #else
    #define LOAD_FRAMEBUFFER_INPUT(idx, v2fname) DXC_DummySubpassVariable##idx
    #define LOAD_FRAMEBUFFER_INPUT_MS(idx, sampleIdx, v2fname) DXC_DummySubpassVariable##idx
    #endif
    #else
        // For floats
    #define FRAMEBUFFER_INPUT_FLOAT(idx) cbuffer hlslcc_SubpassInput_f_##idx { float4 hlslcc_fbinput_##idx; }
    #define FRAMEBUFFER_INPUT_FLOAT_MS(idx) cbuffer hlslcc_SubpassInput_F_##idx { float4 hlslcc_fbinput_##idx[8]; }
    // For halfs
    #define FRAMEBUFFER_INPUT_HALF(idx) cbuffer hlslcc_SubpassInput_h_##idx { half4 hlslcc_fbinput_##idx; }
    #define FRAMEBUFFER_INPUT_HALF_MS(idx) cbuffer hlslcc_SubpassInput_H_##idx { half4 hlslcc_fbinput_##idx[8]; }
    // For ints
    #define FRAMEBUFFER_INPUT_INT(idx) cbuffer hlslcc_SubpassInput_i_##idx { int4 hlslcc_fbinput_##idx; }
    #define FRAMEBUFFER_INPUT_INT_MS(idx) cbuffer hlslcc_SubpassInput_I_##idx { int4 hlslcc_fbinput_##idx[8]; }
    // For uints
    #define FRAMEBUFFER_INPUT_UINT(idx) cbuffer hlslcc_SubpassInput_u_##idx { uint4 hlslcc_fbinput_##idx; }
    #define FRAMEBUFFER_INPUT_UINT_MS(idx) cbuffer hlslcc_SubpassInput_U_##idx { uint4 hlslcc_fbinput_##idx[8]; }

    #define LOAD_FRAMEBUFFER_INPUT(idx, v2fname) hlslcc_fbinput_##idx
    #define LOAD_FRAMEBUFFER_INPUT_MS(idx, sampleIdx, v2fname) hlslcc_fbinput_##idx[sampleIdx]
    #endif

    #else

    // Renderpass inputs: General fallback paths
    #define FRAMEBUFFER_INPUT_FLOAT(idx) TEXTURE2D_FLOAT(_UnityFBInput##idx); float4 _UnityFBInput##idx##_TexelSize
    #define FRAMEBUFFER_INPUT_HALF(idx) TEXTURE2D_HALF(_UnityFBInput##idx); float4 _UnityFBInput##idx##_TexelSize
    #define FRAMEBUFFER_INPUT_INT(idx) TEXTURE2D_INT(_UnityFBInput##idx); float4 _UnityFBInput##idx##_TexelSize
    #define FRAMEBUFFER_INPUT_UINT(idx) TEXTURE2D_UINT(_UnityFBInput##idx); float4 _UnityFBInput##idx##_TexelSize

    #define LOAD_FRAMEBUFFER_INPUT(idx, v2fvertexname) _UnityFBInput##idx.Load(uint3(v2fvertexname.xy, 0))

    #define FRAMEBUFFER_INPUT_FLOAT_MS(idx) Texture2DMS<float4> _UnityFBInput##idx; float4 _UnityFBInput##idx##_TexelSize
    #define FRAMEBUFFER_INPUT_HALF_MS(idx) Texture2DMS<float4> _UnityFBInput##idx; float4 _UnityFBInput##idx##_TexelSize
    #define FRAMEBUFFER_INPUT_INT_MS(idx) Texture2DMS<int4> _UnityFBInput##idx; float4 _UnityFBInput##idx##_TexelSize
    #define FRAMEBUFFER_INPUT_UINT_MS(idx) Texture2DMS<uint4> _UnityFBInput##idx; float4 _UnityFBInput##idx##_TexelSize

    #define LOAD_FRAMEBUFFER_INPUT_MS(idx, sampleIdx, v2fvertexname) _UnityFBInput##idx.Load(uint2(v2fvertexname.xy), sampleIdx)


    #endif

    struct Attributes
    {
        float4 positionOS : POSITION;
        uint vertexID : SV_VertexID;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float3 screenUV : TEXCOORD1;
        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    #if defined(_SPOT)
    float4 _SpotLightScale;
    float4 _SpotLightBias;
    float4 _SpotLightGuard;
    #endif

    Varyings Vertex(Attributes input)
    {
        Varyings output = (Varyings)0;

        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_TRANSFER_INSTANCE_ID(input, output);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        float3 positionOS = input.positionOS.xyz;

        #if defined(_SPOT)
        // Spot lights have an outer angle than can be up to 180 degrees, in which case the shape
        // becomes a capped hemisphere. There is no affine transforms to handle the particular cone shape,
        // so instead we will adjust the vertices positions in the vertex shader to get the tighest fit.
        [flatten] if (any(positionOS.xyz))
        {
            // The hemisphere becomes the rounded cap of the cone.
            positionOS.xyz = _SpotLightBias.xyz + _SpotLightScale.xyz * positionOS.xyz;
            positionOS.xyz = normalize(positionOS.xyz) * _SpotLightScale.w;
            // Slightly inflate the geometry to fit the analytic cone shape.
            // We want the outer rim to be expanded along xy axis only, while the rounded cap is extended along all axis.
            positionOS.xyz = (positionOS.xyz - float3(0, 0, _SpotLightGuard.w)) * _SpotLightGuard.xyz + float3(0, 0, _SpotLightGuard.w);
        }
        #endif

        #if defined(_DIRECTIONAL) || defined(_FOG) || defined(_CLEAR_STENCIL_PARTIAL) || (defined(_SSAO_ONLY) && defined(_SCREEN_SPACE_OCCLUSION))
        output.positionCS = float4(positionOS.xy, UNITY_RAW_FAR_CLIP_VALUE, 1.0); // Force triangle to be on zfar
        #elif defined(_SSAO_ONLY) && !defined(_SCREEN_SPACE_OCCLUSION)
        // Deferred renderer does not know whether there is a SSAO feature or not at the C# scripting level.
        // However, this is known at the shader level because of the shader keyword SSAO feature enables.
        // If the keyword was not enabled, discard the SSAO_only pass by rendering the geometry outside the screen.
        output.positionCS = float4(positionOS.xy, -2, 1.0); // Force triangle to be discarded
        #else
        VertexPositionInputs vertexInput = GetVertexPositionInputs(positionOS.xyz);
        output.positionCS = vertexInput.positionCS;
        #endif

        output.screenUV = output.positionCS.xyw;
        #if UNITY_UV_STARTS_AT_TOP
        output.screenUV.xy = output.screenUV.xy * float2(0.5, -0.5) + 0.5 * output.screenUV.z;
        #else
        output.screenUV.xy = output.screenUV.xy * 0.5 + 0.5 * output.screenUV.z;
        #endif

        return output;
    }

    TEXTURE2D_X(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);
    TEXTURE2D_X_HALF(_GBuffer0);
    TEXTURE2D_X_HALF(_GBuffer1);
    TEXTURE2D_X_HALF(_GBuffer2);

#if _RENDER_PASS_ENABLED

    #define GBUFFER0 0
    #define GBUFFER1 1
    #define GBUFFER2 2
    #define GBUFFER3 3

    FRAMEBUFFER_INPUT_HALF(GBUFFER0);
    FRAMEBUFFER_INPUT_HALF(GBUFFER1);
    FRAMEBUFFER_INPUT_HALF(GBUFFER2);
    FRAMEBUFFER_INPUT_FLOAT(GBUFFER3);
#else
#ifdef GBUFFER_OPTIONAL_SLOT_1
    TEXTURE2D_X_HALF(_GBuffer4);
#endif
#endif

    #if defined(GBUFFER_OPTIONAL_SLOT_2) && _RENDER_PASS_ENABLED
    TEXTURE2D_X_HALF(_GBuffer5);
    #elif defined(GBUFFER_OPTIONAL_SLOT_2)
    TEXTURE2D_X(_GBuffer5);
    #endif
    #ifdef GBUFFER_OPTIONAL_SLOT_3
    TEXTURE2D_X(_GBuffer6);
    #endif

    float4x4 _ScreenToWorld[2];
    SamplerState my_point_clamp_sampler;

    float3 _LightPosWS;
    half3 _LightColor;
    half4 _LightAttenuation; // .xy are used by DistanceAttenuation - .zw are used by AngleAttenuation *for SpotLights)
    half3 _LightDirection;   // directional/spotLights support
    half4 _LightOcclusionProbInfo;
    int _LightFlags;
    int _ShadowLightIndex;

    half4 FragWhite(Varyings input) : SV_Target
    {
        return half4(1.0, 1.0, 1.0, 1.0);
    }

    half4 DeferredShading(Varyings input) : SV_Target
    {
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        // Using SAMPLE_TEXTURE2D is faster than using LOAD_TEXTURE2D on iOS platforms (5% faster shader).
        // Possible reason: HLSLcc upcasts Load() operation to float, which doesn't happen for Sample()?
        float2 screen_uv = (input.screenUV.xy / input.screenUV.z);
        #if _RENDER_PASS_ENABLED
        float d = LOAD_FRAMEBUFFER_INPUT(GBUFFER3, input.positionCS.xy).x;
        half4 gbuffer0 = LOAD_FRAMEBUFFER_INPUT(GBUFFER0, input.positionCS.xy);
        half4 gbuffer1 = LOAD_FRAMEBUFFER_INPUT(GBUFFER1, input.positionCS.xy);
        half4 gbuffer2 = LOAD_FRAMEBUFFER_INPUT(GBUFFER2, input.positionCS.xy);
        #else
        float d        = SAMPLE_TEXTURE2D_X_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, screen_uv, 0).x; // raw depth value has UNITY_REVERSED_Z applied on most platforms.
        half4 gbuffer0 = SAMPLE_TEXTURE2D_X_LOD(_GBuffer0, my_point_clamp_sampler, screen_uv, 0);
        half4 gbuffer1 = SAMPLE_TEXTURE2D_X_LOD(_GBuffer1, my_point_clamp_sampler, screen_uv, 0);
        half4 gbuffer2 = SAMPLE_TEXTURE2D_X_LOD(_GBuffer2, my_point_clamp_sampler, screen_uv, 0);
        #endif
        #ifdef _DEFERRED_SUBTRACTIVE_LIGHTING
        half4 shadowMask = SAMPLE_TEXTURE2D_X_LOD(MERGE_NAME(_, GBUFFER_SHADOWMASK), my_point_clamp_sampler, screen_uv, 0);
        #else
        half4 shadowMask = 1.0;
        #endif

        uint materialFlags = UnpackMaterialFlags(gbuffer0.a);
        bool materialReceiveShadowsOff = (materialFlags & kMaterialFlagReceiveShadowsOff) != 0;
        #if SHADER_API_MOBILE || SHADER_API_SWITCH
        // Specular highlights are still silenced by setting specular to 0.0 during gbuffer pass and GPU timing is still reduced.
        bool materialSpecularHighlightsOff = false;
        #else
        bool materialSpecularHighlightsOff = (materialFlags & kMaterialFlagSpecularHighlightsOff);
        #endif

        #if defined(_DEFERRED_SUBTRACTIVE_LIGHTING)
        // If both lights and geometry are static, then no realtime lighting to perform for this combination.
        [branch] if ((_LightFlags & materialFlags) == kMaterialFlagSubtractiveMixedLighting)
            return half4(0.0, 0.0, 0.0, 0.0); // Cannot discard because stencil must be updated.
        #endif

        #if defined(USING_STEREO_MATRICES)
        int eyeIndex = unity_StereoEyeIndex;
        #else
        int eyeIndex = 0;
        #endif
        float4 posWS = mul(_ScreenToWorld[eyeIndex], float4(input.positionCS.xy, d, 1.0));
        posWS.xyz *= rcp(posWS.w);

        InputData inputData = InputDataFromGbufferAndWorldPosition(gbuffer2, posWS.xyz);

        Light unityLight;

        #if defined(_DIRECTIONAL)
            unityLight.direction = _LightDirection;
            unityLight.color = _LightColor.rgb;
            unityLight.distanceAttenuation = 1.0;
            if (materialReceiveShadowsOff)
                unityLight.shadowAttenuation = 1.0;
            else
            {
                #if defined(_DEFERRED_MAIN_LIGHT) && (defined(_MAIN_LIGHT_SHADOWS) || defined(SHADOWS_SHADOWMASK) || defined(_MIXED_LIGHTING_SUBTRACTIVE))
                    float4 shadowCoord = TransformWorldToShadowCoord(posWS.xyz);
                    unityLight.shadowAttenuation = MainLightShadow(shadowCoord, posWS.xyz, shadowMask, _MainLightOcclusionProbes);
                #elif defined(_DEFERRED_ADDITIONAL_LIGHT_SHADOWS) || defined(SHADOWS_SHADOWMASK) || defined(_MIXED_LIGHTING_SUBTRACTIVE)
                    unityLight.shadowAttenuation = AdditionalLightShadow(_ShadowLightIndex, posWS.xyz, shadowMask, _LightOcclusionProbInfo);
                #else
                    unityLight.shadowAttenuation = 1.0;
                #endif
            }
        #else
            PunctualLightData light;
            light.posWS = _LightPosWS;
            light.radius2 = 0.0; //  only used by tile-lights.
            light.color = float4(_LightColor, 0.0);
            light.attenuation = _LightAttenuation;
            light.spotDirection = _LightDirection;
            light.occlusionProbeInfo = _LightOcclusionProbInfo;
            light.flags = _LightFlags;
            light.shadowLightIndex = _ShadowLightIndex;
            unityLight = UnityLightFromPunctualLightDataAndWorldSpacePosition(light, posWS.xyz, shadowMask, _ShadowLightIndex, materialReceiveShadowsOff);
        #endif

        #if defined(_SCREEN_SPACE_OCCLUSION)
            AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(screen_uv);
            unityLight.color *= aoFactor.directAmbientOcclusion;
        #endif

        half3 color = 0.0.xxx;

        #if defined(_LIT)
            BRDFData brdfData = BRDFDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);
            color = LightingPhysicallyBased(brdfData, unityLight, inputData.normalWS, inputData.viewDirectionWS, materialSpecularHighlightsOff);
        #elif defined(_SIMPLELIT)
            SurfaceData surfaceData = SurfaceDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2, kLightingSimpleLit);
            half3 attenuatedLightColor = unityLight.color * (unityLight.distanceAttenuation * unityLight.shadowAttenuation);
            half3 diffuseColor = LightingLambert(attenuatedLightColor, unityLight.direction, inputData.normalWS);
            half3 specularColor = LightingSpecular(attenuatedLightColor, unityLight.direction, inputData.normalWS, inputData.viewDirectionWS, half4(surfaceData.specular, surfaceData.smoothness), surfaceData.smoothness);
            // TODO: if !defined(_SPECGLOSSMAP) && !defined(_SPECULAR_COLOR), force specularColor to 0 in gbuffer code
            color = diffuseColor * surfaceData.albedo + specularColor;
        #endif

        return half4(color, 0.0);
    }

    half4 FragFog(Varyings input) : SV_Target
    {
        #if _RENDER_PASS_ENABLED
            float d = LOAD_FRAMEBUFFER_INPUT(GBUFFER3, input.positionCS.xy).x;
        #else
            float d = LOAD_TEXTURE2D_X(_CameraDepthTexture, input.positionCS.xy).x;
        #endif
        float eye_z = LinearEyeDepth(d, _ZBufferParams);
        float clip_z = UNITY_MATRIX_P[2][2] * -eye_z + UNITY_MATRIX_P[2][3];
        half fogFactor = ComputeFogFactor(clip_z);
        half fogIntensity = ComputeFogIntensity(fogFactor);
        return half4(unity_FogColor.rgb, fogIntensity);
    }

    half4 FragSSAOOnly(Varyings input) : SV_Target
    {
        float2 screen_uv = (input.screenUV.xy / input.screenUV.z);
        AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(screen_uv);
        half surfaceDataOcclusion = SAMPLE_TEXTURE2D_X_LOD(_GBuffer1, my_point_clamp_sampler, screen_uv, 0).a;
        // What we want is really to apply the mininum occlusion value between the baked occlusion from surfaceDataOcclusion and real-time occlusion from SSAO.
        // But we already applied the baked occlusion during gbuffer pass, so we have to cancel it out here.
        // We must also avoid divide-by-0 that the reciprocal can generate.
        half occlusion = aoFactor.indirectAmbientOcclusion < surfaceDataOcclusion ? aoFactor.indirectAmbientOcclusion * rcp(surfaceDataOcclusion) : 1.0;
        return half4(0.0, 0.0, 0.0, occlusion);
    }

    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        // 0 - Stencil pass
        Pass
        {
            Name "Stencil Volume"

            ZTest LEQual
            ZWrite Off
            ZClip false
            Cull Off
            ColorMask 0

            Stencil {
                Ref [_StencilRef]
                ReadMask [_StencilReadMask]
                WriteMask [_StencilWriteMask]
                CompFront NotEqual
                PassFront Keep
                ZFailFront Invert
                CompBack NotEqual
                PassBack Keep
                ZFailBack Invert
            }

            HLSLPROGRAM
            #pragma exclude_renderers gles

            #pragma multi_compile_vertex _ _SPOT

            #pragma vertex Vertex
            #pragma fragment FragWhite
            //#pragma enable_d3d11_debug_symbols

            ENDHLSL
        }

        // 1 - Deferred Punctual Light (Lit)
        Pass
        {
            Name "Deferred Punctual Light (Lit)"

            ZTest GEqual
            ZWrite Off
            ZClip false
            Cull Front
            Blend One One, Zero One
            BlendOp Add, Add

            Stencil {
                Ref [_LitPunctualStencilRef]
                ReadMask [_LitPunctualStencilReadMask]
                WriteMask [_LitPunctualStencilWriteMask]
                Comp Equal
                Pass Zero
                Fail Keep
                ZFail Keep
            }

            HLSLPROGRAM
            #pragma exclude_renderers gles

            #pragma multi_compile _POINT _SPOT
            #pragma multi_compile_fragment _LIT
            #pragma multi_compile_fragment _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _DEFERRED_ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile_fragment _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ _DEFERRED_SUBTRACTIVE_LIGHTING
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            #pragma vertex Vertex
            #pragma fragment DeferredShading
            //#pragma enable_d3d11_debug_symbols

            ENDHLSL
        }

        // 2 - Deferred Punctual Light (SimpleLit)
        Pass
        {
            Name "Deferred Punctual Light (SimpleLit)"

            ZTest GEqual
            ZWrite Off
            ZClip false
            Cull Front
            Blend One One, Zero One
            BlendOp Add, Add

            Stencil {
                Ref [_SimpleLitPunctualStencilRef]
                ReadMask [_SimpleLitPunctualStencilReadMask]
                WriteMask [_SimpleLitPunctualStencilWriteMask]
                CompBack Equal
                PassBack Zero
                FailBack Keep
                ZFailBack Keep
            }

            HLSLPROGRAM
            #pragma exclude_renderers gles

            #pragma multi_compile _POINT _SPOT
            #pragma multi_compile_fragment _SIMPLELIT
            #pragma multi_compile_fragment _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _DEFERRED_ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile_fragment _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ _DEFERRED_SUBTRACTIVE_LIGHTING
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            #pragma vertex Vertex
            #pragma fragment DeferredShading
            //#pragma enable_d3d11_debug_symbols

            ENDHLSL
        }

        // 3 - Directional Light (Lit)
        Pass
        {
            Name "Deferred Directional Light (Lit)"

            ZTest NotEqual
            ZWrite Off
            Cull Off
            Blend One One, Zero One
            BlendOp Add, Add

            Stencil {
                Ref [_LitDirStencilRef]
                ReadMask [_LitDirStencilReadMask]
                WriteMask [_LitDirStencilWriteMask]
                Comp Equal
                Pass Keep
                Fail Keep
                ZFail Keep
            }

            HLSLPROGRAM
            #pragma exclude_renderers gles

            #pragma multi_compile _DIRECTIONAL
            #pragma multi_compile_fragment _LIT
            #pragma multi_compile_fragment _ _DEFERRED_MAIN_LIGHT
            #pragma multi_compile_fragment _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _DEFERRED_ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile_fragment _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ _DEFERRED_SUBTRACTIVE_LIGHTING
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            #pragma vertex Vertex
            #pragma fragment DeferredShading
            //#pragma enable_d3d11_debug_symbols

            ENDHLSL
        }

        // 4 - Directional Light (SimpleLit)
        Pass
        {
            Name "Deferred Directional Light (SimpleLit)"

            ZTest NotEqual
            ZWrite Off
            Cull Off
            Blend One One, Zero One
            BlendOp Add, Add

            Stencil {
                Ref [_SimpleLitDirStencilRef]
                ReadMask [_SimpleLitDirStencilReadMask]
                WriteMask [_SimpleLitDirStencilWriteMask]
                Comp Equal
                Pass Keep
                Fail Keep
                ZFail Keep
            }

            HLSLPROGRAM
            #pragma exclude_renderers gles

            #pragma multi_compile _DIRECTIONAL
            #pragma multi_compile_fragment _SIMPLELIT
            #pragma multi_compile_fragment _ _DEFERRED_MAIN_LIGHT
            #pragma multi_compile_fragment _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _DEFERRED_ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile_fragment _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ _DEFERRED_SUBTRACTIVE_LIGHTING
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            #pragma vertex Vertex
            #pragma fragment DeferredShading
            //#pragma enable_d3d11_debug_symbols

            ENDHLSL
        }

        // 5 - Legacy fog
        Pass
        {
            Name "Fog"

            ZTest NotEqual
            ZWrite Off
            Cull Off
            Blend OneMinusSrcAlpha SrcAlpha, Zero One
            BlendOp Add, Add

            HLSLPROGRAM
            #pragma exclude_renderers gles

            #pragma multi_compile _FOG
            #pragma multi_compile FOG_LINEAR FOG_EXP FOG_EXP2
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            #pragma vertex Vertex
            #pragma fragment FragFog
            //#pragma enable_d3d11_debug_symbols

            ENDHLSL
        }

        // 6 - Clear stencil partial
        Pass
        {
            Name "ClearStencilPartial"

            ColorMask 0
            ZTest NotEqual
            ZWrite Off
            Cull Off

            Stencil {
                Ref [_ClearStencilRef]
                ReadMask [_ClearStencilReadMask]
                WriteMask [_ClearStencilWriteMask]
                Comp NotEqual
                Pass Zero
                Fail Keep
                ZFail Keep
            }

            HLSLPROGRAM
            #pragma exclude_renderers gles

            #pragma multi_compile _CLEAR_STENCIL_PARTIAL
            #pragma vertex Vertex
            #pragma fragment FragWhite

            ENDHLSL
        }

        // 7 - SSAO Only
        // This pass only runs when there is no fullscreen deferred light rendered (no directional light). It will adjust indirect/baked lighting with realtime occlusion
        // by rendering just before deferred shading pass.
        // This pass is also completely discarded from vertex shader when SSAO renderer feature is not enabled.
        Pass
        {
            Name "SSAOOnly"

            ZTest NotEqual
            ZWrite Off
            Cull Off
            Blend One SrcAlpha, Zero One
            BlendOp Add, Add

            HLSLPROGRAM
            // #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma multi_compile_vertex _SSAO_ONLY
            #pragma multi_compile_vertex _ _SCREEN_SPACE_OCCLUSION

            #pragma vertex Vertex
            #pragma fragment FragSSAOOnly
          //#pragma enable_d3d11_debug_symbols

          ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
