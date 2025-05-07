//
//  StressTester.swift
//  GPU and CPU Stress Test
//
//  Created by Aayush kumar on 07/05/25.
//

import Foundation
import CryptoKit
import Metal
import MetalKit
#if os(macOS)
import IOKit
#endif

class StressTester {
    static let maxDuration: Double = 600
    
    static func runCPUStressTest(level: Double) async -> (Double, [PowerSample], [ThermalSample]) {
        let start = Date()
        let duration = maxDuration * (level / 100.0)
        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        let iterationsPerCore = Int(500_000 * (level / 100.0))
        let input = Data("ExtremeStressTestData".utf8)
        var powerSamples: [PowerSample] = []
        var thermalSamples: [ThermalSample] = []
        
        let monitorTask = Task {
            while !Task.isCancelled {
                let time = -start.timeIntervalSinceNow
                if time >= duration { break }
                powerSamples.append(PowerSample(time: time, power: estimatePower()))
                thermalSamples.append(ThermalSample(time: time, temperature: estimateTemperature()))
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<coreCount {
                group.addTask {
                    for _ in 0..<iterationsPerCore {
                        _ = SHA512.hash(data: input)
                    }
                }
            }
        }
        
        while -start.timeIntervalSinceNow < duration {
            for _ in 0..<1000 {
                _ = SHA512.hash(data: input)
            }
        }
        
        monitorTask.cancel()
        return (-start.timeIntervalSinceNow, powerSamples, thermalSamples)
    }
    
    static func runGPUStressTest(level: Double) async -> (Double, [PowerSample], [ThermalSample]) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = try? device.makeDefaultLibrary(bundle: .main),
              let function = library.makeFunction(name: "complexMatrixMultiply"),
              let pipelineState = try? await device.makeComputePipelineState(function: function) else {
            return (0.0, [], [])
        }
        
        let start = Date()
        let duration = maxDuration * (level / 100.0)
        let size = Int(1024 * (level / 100.0))
        let batchCount = Int(10 * (level / 100.0))
        var powerSamples: [PowerSample] = []
        var thermalSamples: [ThermalSample] = []
        
        let monitorTask = Task {
            while !Task.isCancelled {
                let time = -start.timeIntervalSinceNow
                if time >= duration { break }
                powerSamples.append(PowerSample(time: time, power: estimatePower()))
                thermalSamples.append(ThermalSample(time: time, temperature: estimateTemperature()))
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
        
        while -start.timeIntervalSinceNow < duration {
            let matrixA = (0..<(size * size)).map { _ in Float.random(in: 0...1) }
            let matrixB = (0..<(size * size)).map { _ in Float.random(in: 0...1) }
            var result = [Float](repeating: 0, count: size * size)
            
            guard let bufferA = device.makeBuffer(bytes: matrixA, length: size * size * MemoryLayout<Float>.size, options: .storageModeShared),
                  let bufferB = device.makeBuffer(bytes: matrixB, length: size * size * MemoryLayout<Float>.size, options: .storageModeShared),
                  let bufferResult = device.makeBuffer(bytes: &result, length: size * size * MemoryLayout<Float>.size, options: .storageModeShared) else {
                monitorTask.cancel()
                return (0.0, [], [])
            }
            
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                monitorTask.cancel()
                return (0.0, [], [])
            }
            
            computeEncoder.setComputePipelineState(pipelineState)
            computeEncoder.setBuffer(bufferA, offset: 0, index: 0)
            computeEncoder.setBuffer(bufferB, offset: 0, index: 1)
            computeEncoder.setBuffer(bufferResult, offset: 0, index: 2)
            var matrixSize = UInt32(size)
            var batches = UInt32(batchCount)
            computeEncoder.setBytes(&matrixSize, length: MemoryLayout<UInt32>.size, index: 3)
            computeEncoder.setBytes(&batches, length: MemoryLayout<UInt32>.size, index: 4)
            
            let gridSize = MTLSize(width: size, height: size, depth: 1)
            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
            computeEncoder.endEncoding()
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        monitorTask.cancel()
        return (-start.timeIntervalSinceNow, powerSamples, thermalSamples)
    }
    
    #if os(macOS)
    static func estimatePower() -> Double {
        return Double.random(in: 10...40)
    }
    
    static func estimateTemperature() -> Double {
        return Double.random(in: 30...90)
    }
    #else
    static func estimatePower() -> Double {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return 5.0
        case .fair: return 10.0
        case .serious: return 15.0
        case .critical: return 20.0
        @unknown default: return 10.0
        }
    }
    
    static func estimateTemperature() -> Double {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return 30.0
        case .fair: return 50.0
        case .serious: return 70.0
        case .critical: return 85.0
        @unknown default: return 50.0
        }
    }
    #endif
}

struct PowerSample: Identifiable {
    let id = UUID()
    let time: Double
    let power: Double
}

struct ThermalSample: Identifiable {
    let id = UUID()
    let time: Double
    let temperature: Double
}
