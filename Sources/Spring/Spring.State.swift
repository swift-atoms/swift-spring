extension Spring {
    public struct State {
        public var displacement: Scalar
        public var velocity: Scalar

        public init(displacement: Scalar, velocity: Scalar) {
            self.displacement = displacement
            self.velocity = velocity
        }
    }
}

extension Spring.State: Equatable {}
extension Spring.State: Hashable {}
extension Spring.State: Sendable where Scalar: Sendable {}

extension Spring.State {
    public static var released: Self { Self(displacement: 1, velocity: 0) }
}
