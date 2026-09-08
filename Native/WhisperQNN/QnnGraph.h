// SPDX-License-Identifier: MIT
#pragma once
#include "QnnRuntime.h"
#include <vector>

class QnnGraph {
public:
    static std::unique_ptr<QnnGraph> load(QnnRuntime &runtime, const char *path);
    ~QnnGraph();
    Qnn_TensorV2_t &input(const std::string &name);
    Qnn_TensorV2_t &output(const std::string &name);
    size_t inputCount() const { return inputs.size(); }
    size_t outputCount() const { return outputs.size(); }
    void execute();
    static void requireShape(const Qnn_TensorV2_t &tensor, const std::vector<uint32_t> &dimensions);
private:
    explicit QnnGraph(QnnRuntime &runtime) : runtime(runtime) {}
    Qnn_TensorV2_t &find(std::vector<Qnn_Tensor_t> &tensors, const std::string &name);
    QnnRuntime &runtime;
    QnnSystemContext_Handle_t metadata = nullptr;
    Qnn_ContextHandle_t context = nullptr;
    Qnn_GraphHandle_t graph = nullptr;
    std::vector<char> binary;
    std::vector<Qnn_Tensor_t> inputs, outputs;
    std::vector<std::vector<uint8_t>> buffers;
};
