// SPDX-License-Identifier: MIT
#include "QnnGraph.h"
#include <fstream>
#include <limits>
#include <stdexcept>

std::unique_ptr<QnnGraph> QnnGraph::load(QnnRuntime &runtime, const char *path) {
    auto result = std::unique_ptr<QnnGraph>(new QnnGraph(runtime));
    std::ifstream stream(path, std::ios::binary | std::ios::ate);
    if (!stream || stream.tellg() <= 0) throw std::runtime_error("Encoder artifact is unavailable");
    result->binary.resize(size_t(stream.tellg()));
    stream.seekg(0); stream.read(result->binary.data(), result->binary.size());
    if (!stream) throw std::runtime_error("Incomplete encoder artifact");
    QnnRuntime::check(runtime.system.systemContextCreate(&result->metadata), "QNN metadata creation");
    const QnnSystemContext_BinaryInfo_t *info = nullptr;
    Qnn_ContextBinarySize_t size = 0;
    QnnRuntime::check(runtime.system.systemContextGetBinaryInfo(result->metadata,
        result->binary.data(), result->binary.size(), &info, &size), "QNN artifact metadata");
    if (!info || info->version != QNN_SYSTEM_CONTEXT_BINARY_INFO_VERSION_3)
        throw std::runtime_error("Unsupported encoder artifact metadata");
    const auto &binary = info->contextBinaryInfoV3;
    if (binary.numGraphs != 1 || !binary.graphs || binary.graphs[0].version != QNN_SYSTEM_CONTEXT_GRAPH_INFO_VERSION_3)
        throw std::runtime_error("Unsupported encoder graph structure");
    const auto &graph = binary.graphs[0].graphInfoV3;
    if (!graph.graphName || !graph.numGraphInputs || !graph.numGraphOutputs || !graph.graphInputs || !graph.graphOutputs)
        throw std::runtime_error("Missing encoder graph tensors");
    result->inputs.assign(graph.graphInputs, graph.graphInputs + graph.numGraphInputs);
    result->outputs.assign(graph.graphOutputs, graph.graphOutputs + graph.numGraphOutputs);
    result->buffers.reserve(result->inputs.size() + result->outputs.size());
    for (auto *list : {&result->inputs, &result->outputs}) for (auto &tensor : *list) {
        if (tensor.version != QNN_TENSOR_VERSION_2 || tensor.v2.dataType != QNN_DATATYPE_FLOAT_16 ||
            !tensor.v2.name || !tensor.v2.rank || !tensor.v2.dimensions)
            throw std::runtime_error("Unsupported encoder tensor");
        auto &value = tensor.v2;
        size_t bytes = sizeof(uint16_t);
        for (uint32_t i = 0; i < value.rank; ++i) {
            if (!value.dimensions[i] || bytes > std::numeric_limits<uint32_t>::max() / value.dimensions[i])
                throw std::runtime_error("Invalid encoder tensor dimensions");
            bytes *= value.dimensions[i];
        }
        result->buffers.emplace_back(bytes);
        value.memType = QNN_TENSORMEMTYPE_RAW;
        value.clientBuf = {result->buffers.back().data(), uint32_t(bytes)};
    }
    QnnRuntime::check(runtime.api.contextCreateFromBinary(runtime.backend, runtime.device, nullptr,
        result->binary.data(), result->binary.size(), &result->context, nullptr), "QNN encoder creation");
    QnnRuntime::check(runtime.api.graphRetrieve(result->context, graph.graphName, &result->graph), "QNN encoder lookup");
    return result;
}

QnnGraph::~QnnGraph() {
    if (context) runtime.api.contextFree(context, nullptr);
    if (metadata) runtime.system.systemContextFree(metadata);
}
Qnn_TensorV2_t &QnnGraph::find(std::vector<Qnn_Tensor_t> &tensors, const std::string &name) {
    for (auto &tensor : tensors) if (name == tensor.v2.name) return tensor.v2;
    throw std::runtime_error("Missing encoder tensor: " + name);
}
Qnn_TensorV2_t &QnnGraph::input(const std::string &name) { return find(inputs, name); }
Qnn_TensorV2_t &QnnGraph::output(const std::string &name) { return find(outputs, name); }
void QnnGraph::execute() {
    QnnRuntime::check(runtime.api.graphExecute(graph, inputs.data(), uint32_t(inputs.size()),
        outputs.data(), uint32_t(outputs.size()), nullptr, nullptr), "QNN encoding");
}
void QnnGraph::requireShape(const Qnn_TensorV2_t &tensor, const std::vector<uint32_t> &dimensions) {
    if (tensor.rank != dimensions.size()) throw std::runtime_error("Encoder tensor rank mismatch");
    for (size_t i = 0; i < dimensions.size(); ++i)
        if (tensor.dimensions[i] != dimensions[i]) throw std::runtime_error("Encoder tensor shape mismatch");
}
