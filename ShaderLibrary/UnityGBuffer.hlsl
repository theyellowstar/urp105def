#ifndef UNIVERSAL_GBUFFERUTIL_INCLUDED
#define UNIVERSAL_GBUFFERUTIL_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// inspired from [builtin_shaders]/CGIncludes/UnityGBuffer.cginc

// Non-static meshes with real-time lighting need to write shadow mask, which in that case stores per-object occlusion probe values.
#if !defined(LIGHTMAP_ON) && defined(_MIXED_LIGHTING_SUBTRACTIVE)
#define USE_SHADOWMASK 1
#else
#define USE_SHADOWMASK 0
#endif

#define kLightingInvalid  -1  // No dynamic lighting: can aliase any other material type as they are skipped using stencil
#define kLightingSimpleLit 2  // Simple lit shader
// clearcoat 3
// backscatter 4
// skin 5

#define kMaterialFlagReceiveShadowsOff        1 // Does not receive dynamic shadows
#define kMaterialFlagSpecularHighlightsOff    2 // Does not receivce specular
#define kMaterialFlagSubtractiveMixedLighting 8 // The geometry uses subtractive mixed lighting
#define kMaterialFlagSpecularSetup            4 // Lit material use specular setup instead of metallic setup

#define kLightFlagSubtractiveMixedLighting    8 // The light uses subtractive mixed lighting.

struct FragmentOutput
{
    half4 GBuffer0 : SV_Target0;
    half4 GBuffer1 : SV_Target1;
    half4 GBuffer2 : SV_Target2; // Camera color attachment
    #if defined(_MIXED_LIGHTING_SUBTRACTIVE) || defined(SHADOWS_SHADOWMASK)
    half4 GBuffer3 : SV_Target4;
    #endif
};

float PackMaterialFlags(uint materialFlags)
{
    return materialFlags * (1.0h / 255.0h);
}

uint UnpackMaterialFlags(float packedMaterialFlags)
{
    return uint((packedMaterialFlags * 255.0h) + 0.5h);
}

half3 PackRGBAndMaterialFlagsToRGB(half3 rgb, uint materialFlags)
{
  return rgb * 0.496h + (half3)(materialFlags & uint3(4, 2, 1)) * half3(8.0h, 4.0h, 2.0h);
}

half3 UnpackRGBToRGBAndMaterialFlags(half3 rgb, out uint materialFlags)
{
  materialFlags = (uint)dot(floor(rgb * 2.0h), half3(4.0h, 2.0h, 1.0h));
  return frac(rgb * 2.0h);
}

// This will encode SurfaceData into GBuffer
FragmentOutput SurfaceDataToGbuffer(SurfaceData surfaceData, InputData inputData, half3 globalIllumination, int lightingMode)
{
#if 0 && _GBUFFER_NORMALS_OCT
    float2 octNormalWS = PackNormalOctQuadEncode(inputData.normalWS); // values between [-1, +1], must use fp32 on Nintendo Switch.
    float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
    half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]

    // See SimpleLitInput.hlsl, SampleSpecularSmoothness().
    half packedSmoothness;
    if (lightingMode == kLightingSimpleLit)
        packedSmoothness = 0.1h * log2(surfaceData.smoothness) - 0.1h; // values between [ 0,  1]
    else
        packedSmoothness = surfaceData.smoothness;                     // values between [ 0,  1]
#else
    half2 packedNormalWS = PackNormalOctQuadEncode(inputData.normalWS) * 0.5 + 0.5;                         // values between [0,  1]

    // See SimpleLitInput.hlsl, SampleSpecularSmoothness().
    half packedSmoothness;
    if (lightingMode == kLightingSimpleLit)
        packedSmoothness = 0.1h * log2(surfaceData.smoothness) - 0.1h; // values between [0,  1]
    else
        packedSmoothness = surfaceData.smoothness;       // values between [0,  1]
#endif

    uint materialFlags = 0;

    // SimpleLit does not use _SPECULARHIGHLIGHTS_OFF to disable specular highlights.

#ifdef _RECEIVE_SHADOWS_OFF
    materialFlags |= kMaterialFlagReceiveShadowsOff;
#endif

#if defined(LIGHTMAP_ON) && defined(_MIXED_LIGHTING_SUBTRACTIVE)
    materialFlags |= kMaterialFlagSubtractiveMixedLighting;
#endif

    // 我乱写的
    half reflectivity = max(surfaceData.specular.r, max(surfaceData.specular.g, surfaceData.specular.b));

    FragmentOutput output;
    output.GBuffer0 = half4(PackRGBAndMaterialFlagsToRGB(surfaceData.albedo.rgb, materialFlags), reflectivity);   // albedo          albedo          albedo          materialFlags   (sRGB rendertarget)
    // output.GBuffer1 = half4(0, 0, 0, surfaceData.occlusion);                                // specular        specular        specular        [unused]        (sRGB rendertarget)
#if 0 && _GBUFFER_NORMALS_OCT
    output.GBuffer1 = half4(packedNormalWS, packedSmoothness);                           // encoded-normal  encoded-normal  encoded-normal  packed-smoothness
#else
    output.GBuffer1 = half4(packedNormalWS, surfaceData.occlusion, packedSmoothness);
#endif
    output.GBuffer2 = half4(globalIllumination, 0);                                      // GI              GI              GI              [not_available] (lighting buffer)
    #if defined(_MIXED_LIGHTING_SUBTRACTIVE) || defined(SHADOWS_SHADOWMASK)
    output.GBuffer3 = inputData.shadowMask; // will have unity_ProbesOcclusion value if subtractive lighting is used (baked)
    #endif

    return output;
}

half MetallicFromReflectivity(half reflectivity)
{
  half oneMinusDielectricSpec = kDielectricSpec.a;
  return (reflectivity - kDielectricSpec.r) / oneMinusDielectricSpec;
}

// This decodes the Gbuffer into a SurfaceData struct
SurfaceData SurfaceDataFromGbuffer(half4 gbuffer0, half4 gbuffer1, int lightingMode)
{
    SurfaceData surfaceData;

    uint materialFlags;
    surfaceData.albedo = UnpackRGBToRGBAndMaterialFlags(gbuffer0.rgb, materialFlags);
    surfaceData.occlusion = 1.0; // Not used by SimpleLit material.
    surfaceData.specular = gbuffer1.rgb;

    // 我乱写的
    half reflectivity = gbuffer0.a;
    half metallic = MetallicFromReflectivity(reflectivity);
    surfaceData.specular = lerp(kDieletricSpec.rgb, surfaceData.albedo, metallic);

    half smoothness;

#if 1 || _GBUFFER_NORMALS_OCT
    if (lightingMode == kLightingSimpleLit)
        smoothness = exp2(10.0h * gbuffer1.a + 1.0h);
    else
        smoothness = gbuffer1.a;
#else
    if (lightingMode == kLightingSimpleLit)
        smoothness = exp2(5.0h * gbuffer2.a + 6.0h);
    else
        smoothness = gbuffer1.a * 0.5h + 0.5h;
#endif

    surfaceData.metallic = 0.0; // Not used by SimpleLit material.
    surfaceData.alpha = 1.0; // gbuffer only contains opaque materials
    surfaceData.smoothness = smoothness;

    surfaceData.emission = (half3)0; // Note: this is not made available at lighting pass in this renderer - emission contribution is included (with GI) in the value GBuffer3.rgb, that is used as a renderTarget during lighting
    surfaceData.normalTS = (half3)0; // Note: does this normalTS member need to be in SurfaceData? It looks like an intermediate value

    return surfaceData;
}

// This will encode SurfaceData into GBuffer
FragmentOutput BRDFDataToGbuffer(BRDFData brdfData, InputData inputData, half smoothness, half3 globalIllumination, half occlusion = 1.0)
{
#if 0 && _GBUFFER_NORMALS_OCT
    float2 octNormalWS = PackNormalOctQuadEncode(inputData.normalWS); // values between [-1, +1], must use fp32 on Nintendo Switch.
    float2 remappedOctNormalWS = octNormalWS * 0.5 + 0.5;             // values between [ 0,  1]
    half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);
    half packedSmoothness = smoothness;
#else
    half2 packedNormalWS = PackNormalOctQuadEncode(inputData.normalWS) * 0.5 + 0.5;                       // values between [0,  1]
    half packedSmoothness = smoothness;
#endif

    uint materialFlags = 0;

#ifdef _RECEIVE_SHADOWS_OFF
    materialFlags |= kMaterialFlagReceiveShadowsOff;
#endif

    #ifdef _SPECULAR_SETUP
    half3 specular = brdfData.specular.rgb;
    materialFlags |= kMaterialFlagSpecularSetup;
    // 我乱写的
    half reflectivity = max(brdfData.specular.r, max(brdfData.specular.g, brdfData.specular.b));
    #else
    half3 specular = half3(brdfData.reflectivity, 0.0, 0.0);
    half reflectivity = brdfData.reflectivity;
    #endif

#ifdef _SPECULARHIGHLIGHTS_OFF
    // During the next deferred shading pass, we don't use a shader variant to disable specular calculations.
    // Instead, we can either silence specular contribution when writing the gbuffer, and/or reserve a bit in the gbuffer
    // and use this during shading to skip computations via dynamic branching. Fastest option depends on platforms.
    materialFlags |= kMaterialFlagSpecularHighlightsOff;
    specular = 0.0.xxx;
#endif

#if defined(LIGHTMAP_ON) && defined(_MIXED_LIGHTING_SUBTRACTIVE)
    materialFlags |= kMaterialFlagSubtractiveMixedLighting;
#endif

    FragmentOutput output;
    output.GBuffer0 = half4(PackRGBAndMaterialFlagsToRGB(brdfData.albedo.rgb, materialFlags), reflectivity); // diffuse         diffuse         diffuse         materialFlags   (sRGB rendertarget)
    // output.GBuffer1 = half4(0, 0, 0, occlusion);                        // specular        specular        specular        occlusion    (sRGB rendertarget)
#if 0 && _GBUFFER_NORMALS_OCT
    output.GBuffer1 = half4(packedNormalWS, packedSmoothness);                       // encoded-normal  encoded-normal  encoded-normal  smoothness
#else
    output.GBuffer1 = half4(packedNormalWS, occlusion, packedSmoothness);
#endif
    output.GBuffer2 = half4(globalIllumination, 0);                                  // GI              GI              GI              [not_available] (lighting buffer)
    #if defined(_MIXED_LIGHTING_SUBTRACTIVE) || defined(SHADOWS_SHADOWMASK)
    output.GBuffer3 = inputData.shadowMask; // will have unity_ProbesOcclusion value if subtractive lighting is used (baked)
    #endif

    return output;
}

// This decodes the Gbuffer into a SurfaceData struct
BRDFData BRDFDataFromGbuffer(half4 gbuffer0, half4 gbuffer1)
{
    half3 specular = gbuffer1.rgb;
    uint materialFlags;
    half3 albedo = UnpackRGBToRGBAndMaterialFlags(gbuffer0.rgb, materialFlags);

    half3 brdfDiffuse;
    half3 brdfSpecular;
    half reflectivity;
    half oneMinusReflectivity;

    /*
    if ((materialFlags & kMaterialFlagSpecularSetup) != 0)
    {
      // Specular setup
      reflectivity = ReflectivitySpecular(specular);
      oneMinusReflectivity = half(1.0) - reflectivity;
      brdfDiffuse = albedo * (half3(1.0h, 1.0h, 1.0h) - specular);
      brdfSpecular = specular;
    }
    else
    */
    {
      // Metallic setup
      reflectivity = gbuffer0.a;
      oneMinusReflectivity = 1.0 - reflectivity;
      half metallic = MetallicFromReflectivity(reflectivity);
      brdfDiffuse = albedo * oneMinusReflectivity;
      brdfSpecular = lerp(kDieletricSpec.rgb, albedo, metallic);
    }

#if 1 || _GBUFFER_NORMALS_OCT
    half smoothness = gbuffer1.a;
#else
    half smoothness = gbuffer1.a * 0.5h + 0.5h;
#endif

    BRDFData brdfData = (BRDFData)0;
    half alpha = 1.0; // NOTE: alpha can get modfied, forward writes it out (_ALPHAPREMULTIPLY_ON).
    InitializeBRDFDataDirect(albedo, brdfDiffuse, brdfSpecular, reflectivity, oneMinusReflectivity, smoothness, alpha, brdfData);

    return brdfData;
}

InputData InputDataFromGbufferAndWorldPosition(half4 gbuffer1, float3 wsPos)
{
    InputData inputData;

    inputData.positionWS = wsPos;

#if 0 && _GBUFFER_NORMALS_OCT
    half2 remappedOctNormalWS = Unpack888ToFloat2(gbuffer2.xyz); // values between [ 0,  1]
    half2 octNormalWS = remappedOctNormalWS.xy * 2.0h - 1.0h;    // values between [-1, +1]
    inputData.normalWS = UnpackNormalOctQuadEncode(octNormalWS);
#else
    inputData.normalWS = UnpackNormalOctQuadEncode(gbuffer1.xy * 2.0 - 1.0);  // values between [-1, +1]
#endif

    inputData.viewDirectionWS = SafeNormalize(GetWorldSpaceViewDir(wsPos.xyz));

    // TODO: pass this info?
    inputData.shadowCoord     = (float4)0;
    inputData.fogCoord        = (half  )0;
    inputData.vertexLighting  = (half3 )0;

    inputData.bakedGI = (half3)0; // Note: this is not made available at lighting pass in this renderer - bakedGI contribution is included (with emission) in the value GBuffer3.rgb, that is used as a renderTarget during lighting

    return inputData;
}

#endif // UNIVERSAL_GBUFFERUTIL_INCLUDED
