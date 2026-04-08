# MetallibSupportPkg Forensic Manifest
**Package:** MetallibSupportPkg `15.4-24E248`
**Source:** `/Library/Application Support/Dortania/MetallibSupportPkg/15.4-24E248/`
**Downloaded by:** OCLP 2.4.1 — triggered when macOS Tahoe 26.4 (25E246) download was detected
**Date captured:** 2026-04-08
**Purpose:** OCLP pre-fetches Sequoia 15.4 Metal shader libraries before a Tahoe update so non-Metal GPU support (Sandy Bridge, Ivy Bridge, etc.) can be restored post-update. These `.metallib` files are compiled Metal shaders OCLP injects to bridge the gap between Tahoe's Metal-only renderer and older non-Metal GPUs.

## Package Stats
- **Total size:** 183 MB
- **File count:** 151 `.metallib` files
- **macOS build:** Sequoia 15.4 (build 24E248)
- **Local copy path:** `docs/forensic/MetallibSupportPkg/15.4-24E248/` (gitignored — binary files too large for GitHub)

## File Listing with SHA256 Checksums

| Relative Path | SHA256 |
|---|---|
| `System/Applications/Chess.app/Contents/Resources/default.metallib` | `284107576efd30b07f29639837a35acb80d98ac3328aa0e2323f25697223c09f` |
| `System/Applications/Freeform.app/Contents/Extensions/USDRendererExtension.appex/Contents/Resources/default.metallib` | `5d8ac0e3335e0f04a6fd00ae4a9e4ccde3a051e0fc2691ff967dcabca64334c7` |
| `System/Applications/Freeform.app/Contents/Resources/coreimage.metallib` | `ba8c95040f80d8d66f70684508a5ec2f14cb7017dd80ea73546dba20ea314579` |
| `System/Applications/Freeform.app/Contents/Resources/default.metallib` | `fd2b84bc6a705f19e70337b8d6b887f233f531d75cbb6cee03362ea5cff3a475` |
| `System/Applications/Music.app/Contents/Resources/default.metallib` | `30708c7e43db8564e0926a14d3883105ece55d501c056a782653635997deec3c` |
| `System/Library/CoreImage/CIPassThrough.cifilter/Contents/Resources/CIPassThrough.ci.metallib` | `0e8997e54764e194376dbac2fc1df9facb7f8d730b6cc448cb2974ac395070b6` |
| `System/Library/CoreImage/PortraitFilters.cifilter/Contents/Resources/default.metallib` | `b08f5f0c9201c4b31b34114ed5243b9229137001035d4c28e23dd31ed0f67bec` |
| `System/Library/CoreImage/PortraitFilters.cifilter/Contents/Resources/portrait_filters.metallib` | `f52ebc6eb3446f4af1ef32a3c4a1f1cd9fc8c5c765d8b32a868ca8cf4b86f104` |
| `System/Library/CoreServices/MTLReplayer.app/Contents/Frameworks/MTLReplayController.framework/Versions/A/Resources/default.metallib` | `89c1e74db3daf5358c1919942e3b0032069e011a9b1dca2bb3434808c75d9bf4` |
| `System/Library/ExtensionKit/Extensions/Drift.appex/Contents/Resources/default.metallib` | `df5a85f7afb1fa77e79bebb8b5ca84f3a77eb002e85f810910d2982d277dc44a` |
| `System/Library/ExtensionKit/Extensions/Monterey.appex/Contents/Resources/default.metallib` | `97ad917789b356d179dc995040de19968d439e802958c7214d639f66e067dce9` |
| `System/Library/ExtensionKit/Extensions/WallpaperMacintoshExtension.appex/Contents/Resources/default.metallib` | `2919f6387629bff34654a311a5ee2f29cb891cc866aae636198c6e4f7be6ce41` |
| `System/Library/ExtensionKit/Extensions/WallpaperSequoiaExtension.appex/Contents/Resources/default.metallib` | `c2b76d2d5712a34872f467ed9c34f0751b476801ec0254c16fd467557f8f803a` |
| `System/Library/Frameworks/CoreDisplay.framework/Versions/A/Resources/default.metallib` | `f1f91cb5f06a606d3311d15570b61771c04f8f69b4bb52dccc00047882c0bd27` |
| `System/Library/Frameworks/CoreImage.framework/Versions/A/Resources/CIPortraitBlurStitchableV2.metallib` | `fc05950a9f1169afce8edb85c88ee6770a87c50db74468649feaa82ecf416370` |
| `System/Library/Frameworks/CoreImage.framework/Versions/A/Resources/CIPortraitBlurStitchableV3.metallib` | `274d74e63934ea897f9cf860a2bc1dbbf00c0f48af1ffd0d67ca6a665f31704f` |
| `System/Library/Frameworks/CoreImage.framework/Versions/A/Resources/CIPortraitBlurV2.metallib` | `ba8c95040f80d8d66f70684508a5ec2f14cb7017dd80ea73546dba20ea314579` |
| `System/Library/Frameworks/CoreImage.framework/Versions/A/Resources/CIPortraitBlurV3.metallib` | `ba8c95040f80d8d66f70684508a5ec2f14cb7017dd80ea73546dba20ea314579` |
| `System/Library/Frameworks/CoreImage.framework/Versions/A/Resources/ci_filters.metallib` | `ba8c95040f80d8d66f70684508a5ec2f14cb7017dd80ea73546dba20ea314579` |
| `System/Library/Frameworks/CoreImage.framework/Versions/A/Resources/ci_filters_stitchable.metallib` | `98c1675bed62a78d44929e356531f6887a1024d08bca31cdcc02cb2d6da07c7b` |
| `System/Library/Frameworks/CoreImage.framework/Versions/A/Resources/ci_stdlib.metallib` | `ba8c95040f80d8d66f70684508a5ec2f14cb7017dd80ea73546dba20ea314579` |
| `System/Library/Frameworks/CoreImage.framework/Versions/A/Resources/ci_stdlib_h.metallib` | `ba8c95040f80d8d66f70684508a5ec2f14cb7017dd80ea73546dba20ea314579` |
| `System/Library/Frameworks/CoreImage.framework/Versions/A/Resources/ci_stdlib_stitchable.metallib` | `87d05c036bf9818692c97738fefe2fb91d6fef5a6a3d6d587994a0a6a08167a0` |
| `System/Library/Frameworks/CoreImage.framework/Versions/A/Resources/ci_stdlib_stitchable_h.metallib` | `44e3f8b965f5c5459ac2233663700fd9549b253917cd58709bcbddfa3ecdfef7` |
| `System/Library/Frameworks/CoreImage.framework/Versions/A/Resources/coreui_archive.metallib` | `200790d8eb71a8856407472e06012a61942cfe041a1e540856180f712a576be0` |
| `System/Library/Frameworks/CoreImage.framework/Versions/A/Resources/default.metallib` | `903c5a24281e7b7c3776e73a945368a603bb2447a8743066fd8dcb25356bf765` |
| `System/Library/Frameworks/CoreMediaIO.framework/Versions/A/Resources/ACD.plugin/Contents/Resources/default.metallib` | `fcbe243a7ec3a0e674d669b9e0989a5362ba50ca2b5ba8c7fff1f0fc2f87f8c7` |
| `System/Library/Frameworks/ImageIO.framework/Versions/A/Resources/default.metallib` | `4a0c6489890c0a6d2a90f6b87822e6bc4e7ba51633801317a9fd1ebf137eeec6` |
| `System/Library/Frameworks/Metal.framework/Versions/A/Resources/MTLBVHBuilder.metallib` | `9aa38cb854e569d25823993f4e9c15ab2c932d610e886b0fd00f0860cbcfdaf1` |
| `System/Library/Frameworks/Metal.framework/Versions/A/Resources/MTLECBE.metallib` | `839ada21c5c52e39fea97e77e7ef9d5c5dfac12796221408f8f1a2283d0421b0` |
| `System/Library/Frameworks/Metal.framework/Versions/A/Resources/MTLMeshShaderEmulator.metallib` | `20cb67ae37d8c24858e0cf89ddf556b7622eb0aae341e30e52cc52b50143aad6` |
| `System/Library/Frameworks/Metal.framework/Versions/A/Resources/default.metallib` | `20cb67ae37d8c24858e0cf89ddf556b7622eb0aae341e30e52cc52b50143aad6` |
| `System/Library/Frameworks/MetalFX.framework/Versions/A/Resources/default.metallib` | `78069ff9fabb4db6f997c231c3e5bec3843994dbaf09b27fb8fcfc1e2c3b8ad4` |
| `System/Library/Frameworks/MetalPerformanceShaders.framework/Versions/A/Frameworks/MPSFunctions.framework/Versions/A/Resources/default.metallib` | `7cacd9b627d8abfc31e63f0e04de503219aedbfc1c65bf17c3d0c9656eda34eb` |
| `System/Library/Frameworks/MetalPerformanceShaders.framework/Versions/A/Frameworks/MPSImage.framework/Versions/A/Resources/default.metallib` | `4cae4122a0cafc875f2e7dedfefb9179965e0e9fe2df7f0f0664280a364c4c89` |
| `System/Library/Frameworks/MetalPerformanceShaders.framework/Versions/A/Frameworks/MPSMatrix.framework/Versions/A/Resources/default.metallib` | `2d899e109049f347004d51987f494cee8f044557050430b8b3ef21f1418c3fef` |
| `System/Library/Frameworks/MetalPerformanceShaders.framework/Versions/A/Frameworks/MPSNDArray.framework/Versions/A/Resources/default.metallib` | `3fc2a30b2e4506535d54c836c062fd4f527691ea311cb2d2d160ebbea1e1b8fe` |
| `System/Library/Frameworks/MetalPerformanceShaders.framework/Versions/A/Frameworks/MPSNeuralNetwork.framework/Versions/A/Resources/default.metallib` | `c5f21568eafbc69197f24ae2c8cfdcd56b44bf818c92b564e3590f33d3625539` |
| `System/Library/Frameworks/MetalPerformanceShaders.framework/Versions/A/Frameworks/MPSRayIntersector.framework/Versions/A/Resources/default.metallib` | `065aa8a468e745ac0d0827508d896d6347f009487c2e687ab47ab1929e857a4e` |
| `System/Library/Frameworks/ParavirtualizedGraphics.framework/Versions/A/Resources/default.metallib` | `2f36db26cd957a425a8aecfb38f397ccf0f84c9cbe9824b233c0482898237340` |
| `System/Library/Frameworks/PencilKit.framework/Versions/A/Resources/default.metallib` | `ac6e41570e9c5b741fcd45824ddd928ee0d93ddc7123b95abfd829d605b534a6` |
| `System/Library/Frameworks/QuartzCore.framework/Versions/A/Resources/default.metallib` | `6dbdb54074f6002899b227bc741eb94597a192bc6d501ce94c209d4adcdc5232` |
| `System/Library/Frameworks/SceneKit.framework/Versions/A/Resources/default.metallib` | `e1a03710f9e811b319fc7e720f4688ed1ac4e1ba3e005989e88aa36d2ea74b26` |
| `System/Library/Frameworks/SpriteKit.framework/Versions/A/Resources/default.metallib` | `28ca7ca411991da9054b7ee9e5cff902fb23075d729e2fdd2147bcde27b9089c` |
| `System/Library/Frameworks/StickerKit.framework/Versions/A/Resources/default.metallib` | `f4af37f1b287843587457bef08bc923c7cdb5a047ae92aefeb84909ab30dd220` |
| `System/Library/Frameworks/SwiftUI.framework/Versions/A/Resources/default.metallib` | `fc5dba1e94bc4da53dd1bba79e9d2b129e762195ebdec0a8169c7b5714a47a69` |
| `System/Library/Frameworks/SwiftUICore.framework/Versions/A/Resources/default.metallib` | `fc5dba1e94bc4da53dd1bba79e9d2b129e762195ebdec0a8169c7b5714a47a69` |
| `System/Library/Frameworks/VideoToolbox.framework/Versions/A/Resources/default.metallib` | `0b50db3dca27b29991d0d0df7581da735268b4133da73c836bdd78c118f7c19f` |
| `System/Library/Frameworks/Vision.framework/Versions/A/Resources/ImageFilters.metallib` | `ba8c95040f80d8d66f70684508a5ec2f14cb7017dd80ea73546dba20ea314579` |
| `System/Library/Frameworks/Vision.framework/Versions/A/Resources/default.metallib` | `1d08536342438a850c6bcd71c4e72ac883ba8083c340427c0fa98001589a4e03` |
| `System/Library/PrivateFrameworks/AccelerateGPU.framework/GPUBLAS.metallib` | `eef1e89a4c192f1730628f8f11fa630ececb954ce9db51288b548a3e3df7312d` |
| `System/Library/PrivateFrameworks/AccelerateGPU.framework/Versions/A/Resources/default.metallib` | `7cf5ccdbd995ac1bb2eceee26b869bfb93464a944842d30853f006e9d62577c0` |
| `System/Library/PrivateFrameworks/AltruisticBodyPoseKit.framework/Versions/A/Resources/default.metallib` | `d8b80beb8cce6e44a6faff44cd00cb3f415b7223fc0b0eeed1d595f01cc98391` |
| `System/Library/PrivateFrameworks/AppleDepth.framework/Versions/A/Resources/default.metallib` | `93a5f760a4e7fca75c895408150bac4d414187751572efab78abf948454907ee` |
| `System/Library/PrivateFrameworks/AppleISPEmulator.framework/Versions/A/Resources/default.metallib` | `b71b3818e5e931078ed11ae2b6d8580ca1d074d55970fef3418634f783b75ae8` |
| `System/Library/PrivateFrameworks/AvatarKit.framework/Versions/A/Resources/default.metallib` | `5999f1ef8cef0273c93356c9474aff6928f0d4cf360782f715302b532b1f95ab` |
| `System/Library/PrivateFrameworks/CMImaging.framework/Versions/A/Resources/default.metallib` | `a6bed757c4c24063333efc1a2f9a7fafe1ebe884d84cc40f8d5adfa562a57347` |
| `System/Library/PrivateFrameworks/CMPhoto.framework/Versions/A/Resources/default.metallib` | `1bf96957f89a353077978eb6b8cd9999a7c33afe2dbdc125e9629b8690ff3500` |
| `System/Library/PrivateFrameworks/CameraColorProcessing.framework/Versions/A/Resources/default.metallib` | `83e7cf0b15087b286b92375a1b5b96baf6da8b194f0153d7a71d2c59fa003690` |
| `System/Library/PrivateFrameworks/CinematicFraming.framework/Versions/A/Resources/default.metallib` | `32a6473ecaf56e60a4b398e0b72b564435e8d90818163905fd3427c1a114ca1e` |
| `System/Library/PrivateFrameworks/CoreOCModules.framework/Versions/A/Resources/default.metallib` | `e8664c248731fbf692d53305ada4433ee64353fea349118bf759c2f3ffeef725` |
| `System/Library/PrivateFrameworks/CorePhotogrammetry.framework/Versions/A/Resources/ComputerVision_Tess_Kernels.metallib` | `c46de038810c6fc2216e95832cd32d2b96cb523f1fb8a7b6776bdcab8a2ff07e` |
| `System/Library/PrivateFrameworks/CorePhotogrammetry.framework/Versions/A/Resources/Photogrammetry_MVS_Kernels.metallib` | `058a9964f51e09d0ef5a343d61064ede7d36354a037cba62b0f2a78e653cbce6` |
| `System/Library/PrivateFrameworks/CorePhotogrammetry.framework/Versions/A/Resources/Photogrammetry_Matching_Kernels.metallib` | `32b3b1de5905f27b1b0a7f1257a5d61e474f64aa96b75b7742e1cc917bff118b` |
| `System/Library/PrivateFrameworks/CorePhotogrammetry.framework/Versions/A/Resources/Photogrammetry_Meshing_Kernels.metallib` | `7c215ea2bb1e6881e5eef07b0c90438edc29ef32e15ae50e1dcd1b7bedd02570` |
| `System/Library/PrivateFrameworks/CorePhotogrammetry.framework/Versions/A/Resources/Photogrammetry_Texturing_Kernels.metallib` | `3a45352c5bf1b06bbff9004bc2a55133a4f388ac792b0b1fbe5ec7c56f2da910` |
| `System/Library/PrivateFrameworks/CoreRE.framework/Versions/A/Resources/default.metallib` | `9801137aaae8449ca8a69e6234b9c12ec4d932d2b110b83282924dc29160ecb0` |
| `System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/default.metallib` | `ba8c95040f80d8d66f70684508a5ec2f14cb7017dd80ea73546dba20ea314579` |
| `System/Library/PrivateFrameworks/DeepVideoProcessingCore.framework/VECommonMetalLib.metallib` | `a8ac8fadba26f0d81307904b8287cac9e92aca4b366a0aac938b02ec28b8b1fd` |
| `System/Library/PrivateFrameworks/DeepVideoProcessingCore.framework/frameRateConversionMetalLib.metallib` | `5d7fe9e2e7e82f07c9d28a0ef8c541a9b60ce19460310e7a2be4db44b2739e06` |
| `System/Library/PrivateFrameworks/DeepVideoProcessingCore.framework/opticalFlowMetalLib.metallib` | `31bb1ae383c3ea876647ed6de6081db53c8f5e6b237bb22c744d46c966201f21` |
| `System/Library/PrivateFrameworks/DeepVideoProcessingCore.framework/videoSuperResolutionMetalLib.metallib` | `a878f2cf2795e10c442dd4e8321ef5ea7cd4af9c276dcf9a7ad3e69b43c771a3` |
| `System/Library/PrivateFrameworks/DeepVideoProcessingCore.framework/virtualShutterAngleMetalLib.metallib` | `7d4fea16d954ce585cc0ba53e900f25a4578f0ea48cb1c0014d141be11476e70` |
| `System/Library/PrivateFrameworks/Espresso.framework/Versions/A/Resources/default.metallib` | `4d21cca6b2c8fafe05ab96f6f023b731206f9baa84113fb35b756f31d7504544` |
| `System/Library/PrivateFrameworks/FRC.framework/Versions/A/Resources/default.metallib` | `628b7d766af5461403f3981d269fcd138fba8fdb1b085217c730c725ee0bdc3f` |
| `System/Library/PrivateFrameworks/GESS.framework/Versions/A/Resources/default.metallib` | `c46de038810c6fc2216e95832cd32d2b96cb523f1fb8a7b6776bdcab8a2ff07e` |
| `System/Library/PrivateFrameworks/GPUToolsCapture.framework/Versions/A/Resources/default.metallib` | `b2c76b1f3c2b7df3d73ab2c91c2bf61740c09eccc8631e63979a5279c1877c81` |
| `System/Library/PrivateFrameworks/H13ISPServices.framework/Versions/A/Resources/CalibrateRgbIr.metallib` | `9f27c69b95b99318e161bd30566fbe671b2c26b148f18475de4f07b63d4f73e9` |
| `System/Library/PrivateFrameworks/H16ISPServices.framework/Versions/A/Resources/CalibrateRgbIr.metallib` | `9f27c69b95b99318e161bd30566fbe671b2c26b148f18475de4f07b63d4f73e9` |
| `System/Library/PrivateFrameworks/HDRProcessing.framework/Versions/A/Resources/default.metallib` | `9bc14fb3d0dc988d8e1e1af2e92ae8c1b79aab29dca5809c7db39c265ff7cfb9` |
| `System/Library/PrivateFrameworks/Human.framework/Versions/A/Resources/default.metallib` | `55653b0faa994eca7d7a542acaab40724b17809ee81870e776ce2fe9262275d7` |
| `System/Library/PrivateFrameworks/HumanUI.framework/Versions/A/Resources/default.metallib` | `c8a3117e3fa24b57947a659be2f81c4ab5956a926c2e98131e31ebb0498f109a` |
| `System/Library/PrivateFrameworks/Hydra.framework/Plugins/HydraQLPreviewExtension.appex/Contents/Resources/default.metallib` | `3e9f62ed93b4ceed36ae79d31bf6b2f6cb72553e27d0292872b49392afc509ea` |
| `System/Library/PrivateFrameworks/Hydra.framework/Plugins/HydraQLThumbnailExtension.appex/Contents/Resources/default.metallib` | `3e9f62ed93b4ceed36ae79d31bf6b2f6cb72553e27d0292872b49392afc509ea` |
| `System/Library/PrivateFrameworks/Hydra.framework/Versions/C/Resources/default.metallib` | `3e9f62ed93b4ceed36ae79d31bf6b2f6cb72553e27d0292872b49392afc509ea` |
| `System/Library/PrivateFrameworks/ImageHarmonizationKit.framework/Versions/A/Resources/default.metallib` | `58c8a9dd448ab89c0acc0eea4d22da5591308fde8d8b69e24aeb8de3ed639ec1` |
| `System/Library/PrivateFrameworks/ImagePlaygroundInternal.framework/Versions/A/Resources/default.metallib` | `d80fdc731a4a3566573bb95e048f0f6d5ec52501a4f97d76231b33e816459cd3` |
| `System/Library/PrivateFrameworks/Leonardo.framework/Versions/A/Resources/default.metallib` | `0131851d41459e5c895ffee55c65b4d4c12d8bbb15ddb804d7761634610827a6` |
| `System/Library/PrivateFrameworks/MediaAnalysis.framework/Versions/A/Resources/default.metallib` | `661a3d620c938784dda0da3be23aa20c6f6a922f34b06581be4857215a1fd960` |
| `System/Library/PrivateFrameworks/MediaCoreUI.framework/Versions/A/Resources/default.metallib` | `bf1b0816583c33026b2fc7a6dfe58ac8a7cde759ad1c5c629da72c3ebca4a5f6` |
| `System/Library/PrivateFrameworks/MetalTools.framework/Versions/A/Resources/MTLDebugShaders.metallib` | `aab544e46b474099498eee955d71237f29cdd7dd00c71a046644c1912ddd4dd8` |
| `System/Library/PrivateFrameworks/MetalTools.framework/Versions/A/Resources/MTLGPUDebugAccelerationStructureSupport.metallib` | `4f0a73d13e74f94a69e81e353fe8c10f09bb5286c7940adca3c6f60468f06fdc` |
| `System/Library/PrivateFrameworks/MetalTools.framework/Versions/A/Resources/MTLGPUDebugICBSupport.metallib` | `14fe72862276d822f3661bce93a6fe82410eb83e19b9382e61c29e0013501166` |
| `System/Library/PrivateFrameworks/MetalTools.framework/Versions/A/Resources/MTLLegacySVAccelerationStructureSupport.metallib` | `4f0a73d13e74f94a69e81e353fe8c10f09bb5286c7940adca3c6f60468f06fdc` |
| `System/Library/PrivateFrameworks/MetalTools.framework/Versions/A/Resources/MTLLegacySVICBSupport.metallib` | `53758256c98b8d323e63be1976f97f20eb0998948d7d994a41f17baded454bf4` |
| `System/Library/PrivateFrameworks/MusicUI.framework/Versions/A/Resources/default.metallib` | `ce0b232031de5fd4b01e16aac1a56f22758f006324b016c6d9f7898db2194411` |
| `System/Library/PrivateFrameworks/NeutrinoCore.framework/Versions/A/Resources/default.metallib` | `18366510c5b7a23d0e30e266f0d933de952eb02d5a829ca5c156d16e0245873d` |
| `System/Library/PrivateFrameworks/PassKitUIFoundation.framework/Versions/A/Resources/default.metallib` | `ef3baffc5df56162526a7ccd5d0238dbe9c3d4fd9ba522ef20a0993ed978e244` |
| `System/Library/PrivateFrameworks/PhotoImaging.framework/Versions/A/Resources/default.metallib` | `e08504f70705c4f68d3a4d6200fd148b76787829b38a7ad37f97847a158365e8` |
| `System/Library/PrivateFrameworks/PhotosUICore.framework/Versions/A/Resources/default.metallib` | `056f50a469ef91a26230a73a194622938fe26fb7786f43076bc7539987f4b92d` |
| `System/Library/PrivateFrameworks/PhotosensitivityProcessing.framework/Versions/A/Resources/default.metallib` | `29f3354c5d647ddd8a525b0f6eded26685af553e081a97edeb326ade7b357570` |
| `System/Library/PrivateFrameworks/Portrait.framework/Versions/A/Resources/default.metallib` | `40fd5f262183f393aa61cc3e7326ef3687fc971d9da4295909a7b86d7581d484` |
| `System/Library/PrivateFrameworks/Quagga.framework/Versions/A/Resources/default.metallib` | `77cb6db0835f4672d22f54e9635f0c2c3be569bc2d8ac98f2d3c4e70d275418b` |
| `System/Library/PrivateFrameworks/RenderBox.framework/Versions/A/Resources/default.metallib` | `69b3d4b98681dc81bb4cef136da0aac0569e881249cdeccc3bd573109d8135e1` |
| `System/Library/PrivateFrameworks/SetupAssistantSupportUI.framework/Versions/A/Resources/default.metallib` | `f209feccb172d68d49dbc5a4d749e1926569a346ce4b97c08840ac4301ed5840` |
| `System/Library/PrivateFrameworks/ShaderGraph.framework/Versions/A/Resources/default.metallib` | `f58640567a0fd9541a5488aa594c866199ced09df35d5b01696555c7582a875a` |
| `System/Library/PrivateFrameworks/SiriUI.framework/Versions/A/Resources/default.metallib` | `7861583946993a612d789a26cd42d6e1232956fbb551fa789f8c8c52e77a6cb2` |
| `System/Library/PrivateFrameworks/SiriUICore.framework/Versions/A/Resources/default.metallib` | `79e8d83f473fdf3badd7af22ee4455404631fdc24e891de8e17104290cfe54e1` |
| `System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/Resources/SkyLightShaders.air64.metallib` | `faa61cf07513440b0f31000912461463589df5979502646cea8f2d57d688e2f1` |
| `System/Library/PrivateFrameworks/SpatialConnect.framework/Versions/A/Resources/WarpShaders.metallib` | `d2818484c4b2a732733abe3c91ffce1ee77d3930a89e3bf3cfeb111f58ba3039` |
| `System/Library/PrivateFrameworks/SpatialConnect.framework/Versions/A/Resources/default.metallib` | `379c156077e8ba3c8b7777d6c686307dac9ac2c603a36844574aa435028cd38e` |
| `System/Library/PrivateFrameworks/TextRecognition.framework/Versions/A/Resources/default.metallib` | `fe3e6ec8ecf91bd615c7728dea9f73f92626b1f6104289b654f8674441143251` |
| `System/Library/PrivateFrameworks/Tungsten.framework/Versions/A/Resources/default.metallib` | `8c3781f28f79bf070a2566920794c4d2b9aae513322b1a49d60f17e2ee608c37` |
| `System/Library/PrivateFrameworks/VFX.framework/Versions/A/Resources/default.metallib` | `c92c34975b6ba1eaa4d7bb3f49e733fe86fe1788238acb76db14d6f67bf582f5` |
| `System/Library/PrivateFrameworks/VectorKit.framework/Versions/A/Resources/default.metallib` | `a337f8b0d2e32c7b5b6c50e3d3060dd1b01ab9c68430c54088efdbbb905ea4fe` |
| `System/Library/PrivateFrameworks/VectorKit.framework/Versions/A/Resources/metal_libraries/AlloyCommonLibrary.metallib` | `2c01223a4bb9eee3e2b0e831a859ce9aeb5b66e037a3a3b073134fe8334bf6de` |
| `System/Library/PrivateFrameworks/VideoProcessing.framework/Versions/A/PlugIns/Codecs/VCPRealtimeEncoder.bundle/Contents/Resources/ProcessAccelerate.metallib` | `3c18ff24ac82ba11b576298f02d5210784bca0f47be0df75c48ea23f2dcef217` |
| `System/Library/PrivateFrameworks/VideoProcessing.framework/Versions/A/Resources/ProcessAccelerate.metallib` | `3c18ff24ac82ba11b576298f02d5210784bca0f47be0df75c48ea23f2dcef217` |
| `System/Library/PrivateFrameworks/VideoProcessing.framework/Versions/A/Resources/default.metallib` | `e8b1b96a778d3634824792eb0b4ce64ddeb23993a17a9dc60cf50a476d644ec2` |
| `System/Library/PrivateFrameworks/VisionCore.framework/Versions/A/Resources/default.metallib` | `56ce86cca0c1c65060db9dbc06988f800a74157a0e3e603a03bce8e03db7d850` |
| `System/Library/PrivateFrameworks/VisualGeneration.framework/Versions/A/Resources/NonMaxLineSuppress.ci.metallib` | `ba8c95040f80d8d66f70684508a5ec2f14cb7017dd80ea73546dba20ea314579` |
| `System/Library/PrivateFrameworks/VisualGeneration.framework/Versions/A/Resources/default.metallib` | `65b6921d818f340ac8fd6f0c9f3e5e4ec71e3e46f273857bd3430338fc5e338c` |
| `System/Library/ScreenCaptureKitMetal/ScreenCaptureKitMetal.bundle/Contents/Resources/default.metallib` | `3bb3faaaa9f4275406029b4eebbbc02ee5636e08abedbe1b87a39e9b0a308486` |
| `System/Library/Video/Plug-Ins/AV1DecoderSW.bundle/Contents/Resources/default.metallib` | `cc6f42e96f4caa05a5da446fd3bf8954253ba7a6d4c274fef38ccb60a873b00e` |
| `System/Library/Video/Plug-Ins/AppleAVEEncoder.bundle/Contents/Resources/default.metallib` | `4b748745a46e4aa5381d0a26e3d8a7cd171613f77866e1bea5877ca4a3fd2144` |
| `System/Library/Video/Plug-Ins/AppleGVAHEVCEncoder.bundle/Contents/Resources/AppleGVAHEVCFrameStatistics.metallib` | `29a49cd2fe34a81c1ce910897a9a68a1ff21871f50534731d0174d91f1f2e7f0` |
| `System/Library/VideoProcessors/CCPortrait.bundle/Contents/Resources/CoreImageKernels.ci.metallib` | `a00853f0b991a7cb7c5281b1e5bd6f32e8f4fb3e6c55c71f9849239b54c4b9b5` |
| `System/Library/VideoProcessors/CCPortrait.bundle/Contents/Resources/CoreImageKernels_only.ci.metallib` | `13827908a756673d1f1aa84a853c858bb57f626344b500fb2b26b4fb9061db0e` |
| `System/Library/VideoProcessors/CCPortrait.bundle/Contents/Resources/default.metallib` | `57a77b15e5bf2263c2efc0768fcec03883af87b7229f30a7354a4d3aa0ae6123` |
| `System/iOSSupport/System/Library/Frameworks/ARKit.framework/Versions/A/Resources/default.metallib` | `fab298d11df7c3b059498b32aa4d8bc0507f0eda2da2d05eda0142e224066d2c` |
| `System/iOSSupport/System/Library/Frameworks/PencilKit.framework/Versions/A/Resources/default.metallib` | `6c91f36ea3a696d607cd019c8cc458d7ace149a7338bebeb8c11230ad6778076` |
| `System/iOSSupport/System/Library/Frameworks/SceneKit.framework/Versions/A/Resources/default.metallib` | `ab356691659deb3b238c89e5b515924dfdd8100cabaa8a9527d032066cbd756b` |
| `System/iOSSupport/System/Library/Frameworks/SpriteKit.framework/Versions/A/Resources/default.metallib` | `6dca18ec57fb58ef39bd153c2ba33a86b9612a0c29f32012f8e75831442cb74d` |
| `System/iOSSupport/System/Library/Frameworks/SwiftUI.framework/Versions/A/Resources/default.metallib` | `f89a676eef597d05429eb0c8b0a8610a22528d94b06db91cff403db08b1ee34d` |
| `System/iOSSupport/System/Library/PrivateFrameworks/ActivityRingsUI.framework/Versions/A/Resources/default.metallib` | `f4518d144516bb7eb98a354512cf87fb8b93a0b0a478fbb7d596e156ec1e58f5` |
| `System/iOSSupport/System/Library/PrivateFrameworks/AvatarKit.framework/Versions/A/Resources/default.metallib` | `ba87081dc9a27708a7f065f4f5d7adf5060fbf298d42d6370cc7fe40baf0dc08` |
| `System/iOSSupport/System/Library/PrivateFrameworks/ChatKit.framework/Versions/A/Resources/default.metallib` | `90eec3363f701563f6b2c625d53ddca66a5918ae8befc0701103c18da2394069` |
| `System/iOSSupport/System/Library/PrivateFrameworks/HomeAccessoryControlUI.framework/Versions/A/Resources/default.metallib` | `7d857c7283e197a4876b6e9a64b586aabf32a5bd74de3d12b4e3ddeeac9f086a` |
| `System/iOSSupport/System/Library/PrivateFrameworks/ImagePlaygroundInternal.framework/Versions/A/Resources/default.metallib` | `6b6d02f45dae737a00abc077878e4b14038a64ec974790cbabe8d8fe7defdf57` |
| `System/iOSSupport/System/Library/PrivateFrameworks/MediaCoreUI.framework/Versions/A/Resources/default.metallib` | `89cfe1f94c259aa922a8348b68f312d2a011e46ef57a276112a4990490706b88` |
| `System/iOSSupport/System/Library/PrivateFrameworks/PassKitUIFoundation.framework/Versions/A/Resources/default.metallib` | `4d85e3915162fb9dc1e6062fd9026b055785cf4ccc31d831e4733bacfb8229ba` |
| `System/iOSSupport/System/Library/PrivateFrameworks/TSReading.framework/Versions/A/Resources/KeynoteMetalLibrary.metallib` | `7d8c815fa63ee182942da4c8642dc398e8b22576ac410dd8b321b455c570e95a` |
| `System/iOSSupport/System/Library/PrivateFrameworks/TSReading.framework/Versions/A/Resources/TSDDefaultMetalLibrary.metallib` | `662a7f45d47cb1c7400e9640852675e606d13d44ab24fcc20f9d643eaa312475` |
| `System/iOSSupport/System/Library/PrivateFrameworks/TextInputUI.framework/Versions/A/Resources/default.metallib` | `4e65e789333ab53a67e95a7a695c67ebb298a2e3e25ba23d6a9f8caa2ae32c77` |
| `System/iOSSupport/System/Library/PrivateFrameworks/Tungsten.framework/Versions/A/Resources/default.metallib` | `c8a40e0e1cb2932a09b49dddcf4f97edb419bc457a092ebfae2bcb870dd67cae` |
| `System/iOSSupport/System/Library/PrivateFrameworks/VFX.framework/Versions/A/Resources/default.metallib` | `7d864de957b120f614aac073aafeaaf159cbb0e9c4c7e3d18241936ace8c52fa` |
| `System/iOSSupport/System/Library/PrivateFrameworks/VisionKitInternal.framework/Versions/A/Resources/default.metallib` | `46dd5bab65fcdbb940af42b65f461954d999df557dce96deffa31ea5a3b8394e` |
| `System/iOSSupport/System/Library/PrivateFrameworks/WeatherMaps.framework/Versions/A/Resources/WeatherMapsMetalLib.metallib` | `4b88e628dfaf6621411eb76da508360c7d491961baf9fe36c460cf19ffad4a88` |
| `System/iOSSupport/System/Library/PrivateFrameworks/WeatherUI.framework/Versions/A/Resources/ForegroundEffectShaders.metallib` | `96d807d7b6a2816dd92a52f1689ea44039d2c8e7294a59b5850adfc68c8b176c` |
| `System/iOSSupport/System/Library/PrivateFrameworks/WeatherUI.framework/Versions/A/Resources/default.metallib` | `84bbe6351d699bf2c82a56e5eeeae5d1a847250e42aba68835e0c1734e2c4418` |

*Manifest generated 2026-04-08 — binaries gitignored, checksums kept for forensic reference.*
