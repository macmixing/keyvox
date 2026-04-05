@preconcurrency import CoreML
import Foundation

enum PocketTTSInferenceTypes {
    struct KVCacheState {
        var caches: [MLMultiArray]
        var positions: [MLMultiArray]
    }

    struct MimiState {
        var tensors: [String: MLMultiArray]
    }

    enum CondStepOutput {
        static let cacheKeys = [
            "new_cache_1_internal_tensor_assign_2",
            "new_cache_3_internal_tensor_assign_2",
            "new_cache_5_internal_tensor_assign_2",
            "new_cache_7_internal_tensor_assign_2",
            "new_cache_9_internal_tensor_assign_2",
            "new_cache_internal_tensor_assign_2",
        ]

        static let positionKeys = [
            "var_445",
            "var_864",
            "var_1283",
            "var_1702",
            "var_2121",
            "var_2365",
        ]
    }

    enum FlowLMOutput {
        static let transformerOut = "input"
        static let eosLogit = "var_2582"
        static let cacheKeys = [
            "new_cache_1_internal_tensor_assign_2",
            "new_cache_3_internal_tensor_assign_2",
            "new_cache_5_internal_tensor_assign_2",
            "new_cache_7_internal_tensor_assign_2",
            "new_cache_9_internal_tensor_assign_2",
            "new_cache_internal_tensor_assign_2",
        ]

        static let positionKeys = [
            "var_458",
            "var_877",
            "var_1296",
            "var_1715",
            "var_2134",
            "var_2553",
        ]
    }

    enum MimiOutput {
        static let audio = "var_821"
        static let stateMappings: [(input: String, output: String)] = [
            ("upsample_partial", "var_82"),
            ("attn0_cache", "var_262"),
            ("attn0_offset", "var_840"),
            ("attn0_end_offset", "new_end_offset_1"),
            ("attn1_cache", "var_479"),
            ("attn1_offset", "var_843"),
            ("attn1_end_offset", "new_end_offset"),
            ("conv0_prev", "var_607"),
            ("conv0_first", "conv0_first"),
            ("convtr0_partial", "var_634"),
            ("res0_conv0_prev", "var_660"),
            ("res0_conv0_first", "res0_conv0_first"),
            ("res0_conv1_prev", "res0_conv1_prev"),
            ("res0_conv1_first", "res0_conv1_first"),
            ("convtr1_partial", "var_700"),
            ("res1_conv0_prev", "var_726"),
            ("res1_conv0_first", "res1_conv0_first"),
            ("res1_conv1_prev", "res1_conv1_prev"),
            ("res1_conv1_first", "res1_conv1_first"),
            ("convtr2_partial", "var_766"),
            ("res2_conv0_prev", "var_792"),
            ("res2_conv0_first", "res2_conv0_first"),
            ("res2_conv1_prev", "res2_conv1_prev"),
            ("res2_conv1_first", "res2_conv1_first"),
            ("conv_final_prev", "var_824"),
            ("conv_final_first", "conv_final_first"),
        ]
    }
}
