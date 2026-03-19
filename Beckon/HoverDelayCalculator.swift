import Foundation

enum HoverDelayCalculator {
    static func effectiveDelayMs(
        baseDelayMs: Double,
        lastEventTimestamp: TimeInterval,
        currentTimestamp: TimeInterval,
        deltaX: CGFloat,
        deltaY: CGFloat,
        velocitySensitivity: Double,
        maxDelayMs: Double = 500
    ) -> Double {
        guard lastEventTimestamp > 0 else {
            return baseDelayMs
        }

        let timeDelta = currentTimestamp - lastEventTimestamp
        guard timeDelta > 0 else {
            return baseDelayMs
        }

        let distance = Double(sqrt(deltaX * deltaX + deltaY * deltaY))
        let speedPPS = distance / timeDelta
        let velocityBonus = speedPPS * max(0, velocitySensitivity)
        return min(maxDelayMs, baseDelayMs + velocityBonus)
    }
}