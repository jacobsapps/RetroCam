import Foundation

struct RetroShaderConfig {
    var pixelSize: Float = 8.0
    var scanlineIntensity: Float = 0.3
    var scanlineFrequency: Float = 0.8
    var glitchEnabled: Bool = true
    
    static let standard = RetroShaderConfig()
}