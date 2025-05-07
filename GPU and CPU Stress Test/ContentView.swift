//
//  ContentView.swift
//  GPU and CPU Stress Test
//
//  Created by Aayush kumar on 07/05/25.
//

import SwiftUI
import Charts
import CryptoKit

struct ContentView: View {
    @State private var stressLevel: Double = 10.0
    @State private var result: String = "No test run yet"
    @State private var isTesting: Bool = false
    @State private var showGraph: Bool = false
    @State private var powerData: [PowerSample] = []
    @State private var thermalData: [ThermalSample] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Extreme CPU/GPU Stress Test")
                .font(.title)
            
            Slider(value: $stressLevel, in: 10...100, step: 10) {
                Text("Stress Level: \(Int(stressLevel))%")
            }
            .padding()
            
            HStack(spacing: 20) {
                Button(action: {
                    isTesting = true
                    Task {
                        let (time, power, thermal) = await StressTester.runCPUStressTest(level: stressLevel)
                        result = String(format: "CPU Test: %.2f seconds", time)
                        powerData = power
                        thermalData = thermal
                        showGraph = true
                        isTesting = false
                    }
                }) {
                    Text("CPU Test")
                        .frame(width: 100, height: 40)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isTesting)
                
                Button(action: {
                    isTesting = true
                    Task {
                        let (time, power, thermal) = await StressTester.runGPUStressTest(level: stressLevel)
                        result = String(format: "GPU Test: %.2f seconds", time)
                        powerData = power
                        thermalData = thermal
                        showGraph = true
                        isTesting = false
                    }
                }) {
                    Text("GPU Test")
                        .frame(width: 100, height: 40)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isTesting)
            }
            
            Text(result)
                .font(.system(size: 16, weight: .medium))
                .padding()
            
            if isTesting {
                ProgressView()
            }
            
            if showGraph {
                Chart {
                    ForEach(powerData) { sample in
                        LineMark(
                            x: .value("Time", sample.time),
                            y: .value("Power (W)", sample.power)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: 0...50)
                .chartXScale(domain: 0...900)
                .chartXAxisLabel("Time (s)")
                .chartYAxisLabel("Power (W)")
                
                Chart {
                    ForEach(thermalData) { sample in
                        LineMark(
                            x: .value("Time", sample.time),
                            y: .value("Temp (°C)", sample.temperature)
                        )
                        .foregroundStyle(.red)
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: 20...100)
                .chartXScale(domain: 0...900)
                .chartXAxisLabel("Time (s)")
                .chartYAxisLabel("Temperature (°C)")
            }
        }
        .padding()
    }
}
