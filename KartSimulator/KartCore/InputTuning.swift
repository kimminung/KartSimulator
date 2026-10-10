import Foundation

public struct InputTuning: Sendable {
    public var spreadHalf: Float
    public var spreadFull: Float
    public var spreadHysteresis: Float
    public var releaseGrace: TimeInterval
    public var pinchDebounce: TimeInterval
    public var staleTimeout: TimeInterval
    public var distanceSmoothing: Float

    public init(
        spreadHalf: Float = 0.22,
        spreadFull: Float = 0.40,
        spreadHysteresis: Float = 0.03,
        releaseGrace: TimeInterval = 0.120,
        pinchDebounce: TimeInterval = 0.040,
        staleTimeout: TimeInterval = 0.300,
        distanceSmoothing: Float = 0.25
    ) {
        self.spreadHalf = spreadHalf
        self.spreadFull = spreadFull
        self.spreadHysteresis = spreadHysteresis
        self.releaseGrace = releaseGrace
        self.pinchDebounce = pinchDebounce
        self.staleTimeout = staleTimeout
        self.distanceSmoothing = distanceSmoothing
    }
}
