extension Spring {
    public enum Error: Swift::Error, Equatable, Sendable {
        case mass
        case stiffness
        case damping
    }
}
