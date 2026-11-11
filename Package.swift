// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "swift-spring",
    platforms: [.macOS(.v27), .iOS(.v27), .tvOS(.v27), .watchOS(.v27), .visionOS(.v27)],
    products: [.library(name: "Spring", targets: ["Spring"])],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-exponential.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-trigonometry.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Spring",
            dependencies: [
                .product(name: "Exponential", package: "swift-exponential"),
                .product(name: "Trigonometry", package: "swift-trigonometry"),
            ]
        ),
        .testTarget(
            name: "Spring Tests",
            dependencies: [
                .target(name: "Spring")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
