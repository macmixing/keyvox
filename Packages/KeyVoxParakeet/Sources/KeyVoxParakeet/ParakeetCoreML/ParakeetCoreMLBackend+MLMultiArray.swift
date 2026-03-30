import Foundation
import CoreML

extension ParakeetCoreMLBackend {
    func makeFloat32Array(shape: [Int]) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: shape.map(NSNumber.init(value:)), dataType: .float32)
        zero(array)
        return array
    }

    func makeInt32Array(shape: [Int]) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: shape.map(NSNumber.init(value:)), dataType: .int32)
        zero(array)
        return array
    }

    func fill(_ array: MLMultiArray, with values: [Float]) {
        for (index, value) in values.enumerated() {
            set(value, in: array, atLinearIndex: index)
        }
    }

    func offset(in array: MLMultiArray, indices: [Int]) -> Int {
        zip(indices, array.strides).reduce(0) { partialResult, pair in
            partialResult + (pair.0 * pair.1.intValue)
        }
    }

    func set(_ value: Float, in array: MLMultiArray, at indices: [Int]) {
        set(value, in: array, atLinearIndex: offset(in: array, indices: indices))
    }

    func set(_ value: Float, in array: MLMultiArray, atLinearIndex index: Int) {
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
        pointer[index] = value
    }

    func set(_ value: Int32, in array: MLMultiArray, at indices: [Int]) {
        let pointer = array.dataPointer.bindMemory(to: Int32.self, capacity: array.count)
        pointer[offset(in: array, indices: indices)] = value
    }

    func zero(_ array: MLMultiArray) {
        switch array.dataType {
        case .float32:
            let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
            pointer.initialize(repeating: 0, count: array.count)
        case .int32:
            let pointer = array.dataPointer.bindMemory(to: Int32.self, capacity: array.count)
            pointer.initialize(repeating: 0, count: array.count)
        default:
            break
        }
    }

    func float32Value(in array: MLMultiArray, at indices: [Int]) -> Float {
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
        return pointer[offset(in: array, indices: indices)]
    }

    func int32Value(in array: MLMultiArray, at indices: [Int]) -> Int32 {
        let pointer = array.dataPointer.bindMemory(to: Int32.self, capacity: array.count)
        return pointer[offset(in: array, indices: indices)]
    }
}
