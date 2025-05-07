//
//  MatrixShader.metal
//  GPU and CPU Stress Test
//
//  Created by Aayush kumar on 07/05/25.
//

#include <metal_stdlib>
using namespace metal;


#include <metal_stdlib>
using namespace metal;

kernel void complexMatrixMultiply(device float *matrixA [[buffer(0)]],
                                 device float *matrixB [[buffer(1)]],
                                 device float *result [[buffer(2)]],
                                 constant uint &size [[buffer(3)]],
                                 constant uint &batches [[buffer(4)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= size || gid.y >= size) return;
    
    float sum = 0.0;
    for (uint b = 0; b < batches; b++) {
        for (uint i = 0; i < size; i++) {
            sum += matrixA[gid.y * size + i] * matrixB[i * size + gid.x];
        }
        sum = sin(sum) * cos(sum);
    }
    result[gid.y * size + gid.x] = sum;
}
