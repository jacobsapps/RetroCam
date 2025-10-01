import UIKit
import CoreHaptics

enum Haptics {
    static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    static let selection = UISelectionFeedbackGenerator()
    private static var hapticEngine: CHHapticEngine?

    static func impact() {
        impactHeavy.prepare()
        impactHeavy.impactOccurred()
    }
    
    static func cutoutCapture() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            impactHeavy.prepare()
            impactHeavy.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                impactHeavy.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                impactHeavy.impactOccurred(intensity: 0.8)
            }
            return
        }
        
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            
            var events: [CHHapticEvent] = []
            
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0
            ))
            
            for i in 0..<3 {
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.05 + Double(i) * 0.04,
                    duration: 0.03
                ))
            }
            
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0.2
            ))
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                engine.stop()
            }
        } catch {
            impactHeavy.prepare()
            impactHeavy.impactOccurred()
        }
    }
}