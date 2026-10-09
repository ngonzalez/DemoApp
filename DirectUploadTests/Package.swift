// swift-tools-version: 6.0
// Tests of DemoApp's DirectUpload.swift (linked into Sources/DirectUpload),
// without an Xcode test target: `swift test` in this folder
import PackageDescription

let package = Package(
    name: "DirectUploadTests",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DirectUpload", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "DirectUploadTests", dependencies: ["DirectUpload"]),
    ]
)
