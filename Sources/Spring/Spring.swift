public struct Spring<Scalar: BinaryFloatingPoint> {
    public let mass: Scalar
    public let stiffness: Scalar
    public let damping: Scalar

    public init(mass: Scalar, stiffness: Scalar, damping: Scalar) throws(Error) {
        guard mass.isFinite, mass > 0 else { throw .mass }
        guard stiffness.isFinite, stiffness > 0 else { throw .stiffness }
        guard damping.isFinite, damping >= 0 else { throw .damping }
        self.mass = mass
        self.stiffness = stiffness
        self.damping = damping
    }
}

extension Spring: Equatable {}
extension Spring: Hashable {}
extension Spring: Sendable where Scalar: Sendable {}

extension Spring {
    public init(frequency: Scalar, ratio: Scalar) throws(Error) {
        guard frequency.isFinite, frequency > 0 else { throw .stiffness }
        guard ratio.isFinite, ratio >= 0 else { throw .damping }
        try self.init(mass: 1, stiffness: frequency * frequency, damping: 2 * ratio * frequency)
    }

    public var frequency: Scalar { (stiffness / mass).squareRoot() }

    public var ratio: Scalar { damping / (2 * (stiffness * mass).squareRoot()) }

    public var regime: Regime {
        let discriminant = damping * damping - 4 * mass * stiffness
        return discriminant < 0 ? .under : discriminant > 0 ? .over : .critical
    }

    public func energy(of state: State) -> Scalar {
        (mass * state.velocity * state.velocity + stiffness * state.displacement * state.displacement) / 2
    }
}

extension Spring where Scalar: Exponential.`Protocol` & Trigonometry.Circular {
    public func state(at time: Scalar, from initial: State = .released) -> State {
        guard time != 0 else { return initial }
        let decay = damping / (2 * mass)
        let square = stiffness / mass
        let pull = initial.velocity + decay * initial.displacement
        switch regime {
        case .under:
            let frequency = (square - decay * decay).squareRoot()
            let envelope = Scalar.exp(-decay * time)
            let cosine = Scalar.cos(frequency * time)
            let sine = Scalar.sin(frequency * time)
            return State(
                displacement: envelope * (initial.displacement * cosine + pull / frequency * sine),
                velocity: envelope
                    * (initial.velocity * cosine - (decay * initial.velocity + square * initial.displacement) / frequency * sine)
            )

        case .critical:
            let envelope = Scalar.exp(-decay * time)
            return State(
                displacement: envelope * (initial.displacement + pull * time),
                velocity: envelope * (initial.velocity - decay * pull * time)
            )

        case .over:
            let spread = (decay * decay - square).squareRoot()
            let slow = spread - decay
            let fast = -spread - decay
            let first = (initial.velocity - fast * initial.displacement) / (2 * spread)
            let second = (slow * initial.displacement - initial.velocity) / (2 * spread)
            let slower = first * Scalar.exp(slow * time)
            let faster = second * Scalar.exp(fast * time)
            return State(displacement: slower + faster, velocity: slow * slower + fast * faster)
        }
    }

    public func displacement(at time: Scalar, from initial: State = .released) -> Scalar {
        state(at: time, from: initial).displacement
    }

    public func velocity(at time: Scalar, from initial: State = .released) -> Scalar {
        state(at: time, from: initial).velocity
    }

    public func settling(within tolerance: Scalar, from initial: State = .released) -> Scalar? {
        precondition(tolerance > 0, "A settling tolerance is positive")
        let decay = damping / (2 * mass)
        let square = stiffness / mass
        let pull = initial.velocity + decay * initial.displacement
        let amplitude: Scalar
        let rate: Scalar
        switch regime {
        case .under:
            let frequency = (square - decay * decay).squareRoot()
            amplitude = (initial.displacement * initial.displacement + pull / frequency * (pull / frequency)).squareRoot()
            rate = decay

        case .critical:
            amplitude = abs(initial.displacement) + 2 * abs(pull) / (Scalar.exp(1) * decay)
            rate = decay / 2

        case .over:
            let spread = (decay * decay - square).squareRoot()
            let first = (initial.velocity - (-spread - decay) * initial.displacement) / (2 * spread)
            let second = ((spread - decay) * initial.displacement - initial.velocity) / (2 * spread)
            amplitude = abs(first) + abs(second)
            rate = decay - spread
        }
        guard amplitude > tolerance else { return 0 }
        guard rate > 0 else { return nil }
        return Scalar.log(amplitude / tolerance) / rate
    }
}
