// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PhotoSorter",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PhotoSorter",
            path: "Sources/PhotoSorter"
        )
    ]
)
