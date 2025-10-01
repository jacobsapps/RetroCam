import Metal
import CoreVideo
import UIKit

final class MetalShaderRenderer {
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let textureCache: CVMetalTextureCache
    private let kernels: [String: MTLComputePipelineState]
    private let startTime: CFAbsoluteTime
    
    var config: RetroShaderConfig
    var filterType: FilterType = .eightBit
    
    init?(config: RetroShaderConfig = .standard) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.startTime = CFAbsoluteTimeGetCurrent()
        self.config = config
        
        var textureCache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache) == kCVReturnSuccess,
              let cache = textureCache else {
            return nil
        }
        self.textureCache = cache
        
        guard let library = device.makeDefaultLibrary() else {
            return nil
        }
        
        let kernelNames = ["pixellate", "crtScreen", "glitch", "passthrough", 
                          "threeDGlasses", "spectral", "alien", "alien2", "inversion"]
        var loadedKernels: [String: MTLComputePipelineState] = [:]
        
        do {
            for name in kernelNames {
                guard let function = library.makeFunction(name: name) else {
                    return nil
                }
                loadedKernels[name] = try device.makeComputePipelineState(function: function)
            }
            self.kernels = loadedKernels
        } catch {
            return nil
        }
    }
    
    func render(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        switch filterType {
        case .normal:
            return renderNormal(pixelBuffer: pixelBuffer)
        case .eightBit:
            return renderEightBit(pixelBuffer: pixelBuffer)
        case .threeDGlasses:
            return renderSinglePass(pixelBuffer: pixelBuffer, kernelName: "threeDGlasses")
        case .spectral:
            return renderSinglePass(pixelBuffer: pixelBuffer, kernelName: "spectral")
        case .alien:
            return renderSinglePass(pixelBuffer: pixelBuffer, kernelName: "alien")
        case .alien2:
            return renderSinglePass(pixelBuffer: pixelBuffer, kernelName: "alien2")
        case .inversion:
            return renderSinglePass(pixelBuffer: pixelBuffer, kernelName: "inversion")
        }
    }
    
    private func renderNormal(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        return pixelBuffer
    }
    
    private func renderSinglePass(pixelBuffer: CVPixelBuffer, kernelName: String) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard let kernel = kernels[kernelName],
              let inputTexture = makeTexture(from: pixelBuffer),
              let outputBuffer = createPixelBuffer(width: width, height: height),
              let outputTexture = makeTexture(from: outputBuffer),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        
        computeEncoder.setComputePipelineState(kernel)
        computeEncoder.setTexture(inputTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return outputBuffer
    }
    
    private func renderEightBit(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard let pixellateKernel = kernels["pixellate"],
              let crtKernel = kernels["crtScreen"],
              let glitchKernel = kernels["glitch"],
              let inputTexture = makeTexture(from: pixelBuffer),
              let tempBuffer1 = createPixelBuffer(width: width, height: height),
              let tempTexture1 = makeTexture(from: tempBuffer1),
              let tempBuffer2 = createPixelBuffer(width: width, height: height),
              let tempTexture2 = makeTexture(from: tempBuffer2),
              let outputBuffer = createPixelBuffer(width: width, height: height),
              let outputTexture = makeTexture(from: outputBuffer),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        
        computeEncoder.setComputePipelineState(pixellateKernel)
        computeEncoder.setTexture(inputTexture, index: 0)
        computeEncoder.setTexture(tempTexture1, index: 1)
        var pixelSizeBuffer = config.pixelSize
        computeEncoder.setBytes(&pixelSizeBuffer, length: MemoryLayout<Float>.size, index: 0)
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        
        computeEncoder.setComputePipelineState(crtKernel)
        computeEncoder.setTexture(tempTexture1, index: 0)
        computeEncoder.setTexture(tempTexture2, index: 1)
        var timeBuffer = Float(CFAbsoluteTimeGetCurrent() - startTime)
        computeEncoder.setBytes(&timeBuffer, length: MemoryLayout<Float>.size, index: 0)
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        
        if config.glitchEnabled {
            computeEncoder.setComputePipelineState(glitchKernel)
            computeEncoder.setTexture(tempTexture2, index: 0)
            computeEncoder.setTexture(outputTexture, index: 1)
            var timeBuffer = Float(CFAbsoluteTimeGetCurrent() - startTime)
            computeEncoder.setBytes(&timeBuffer, length: MemoryLayout<Float>.size, index: 0)
            computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        } else {
            computeEncoder.setComputePipelineState(glitchKernel)
            computeEncoder.setTexture(tempTexture2, index: 0)
            computeEncoder.setTexture(outputTexture, index: 1)
            var timeBuffer = Float(0)
            computeEncoder.setBytes(&timeBuffer, length: MemoryLayout<Float>.size, index: 0)
            computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        }
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return outputBuffer
    }
    
    private func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var texture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &texture
        )
        
        guard status == kCVReturnSuccess, let metalTexture = texture else {
            return nil
        }
        
        return CVMetalTextureGetTexture(metalTexture)
    }
    
    private func createPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        return status == kCVReturnSuccess ? pixelBuffer : nil
    }
}