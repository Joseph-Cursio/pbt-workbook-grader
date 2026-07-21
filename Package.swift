// swift-tools-version: 6.0
import PackageDescription

// pbt-workbook-grader — the shared, public grader machinery for the Properties,
// Worked lab.
//
// This is the single source of truth for the two grader layers, consumed by
// both the private product (`pbt-workbook`) and the public sampler
// (`pbt-workbook-sampler`). Per the book's planning/workbook-repo-topology.md the
// grader is *infrastructure* — the format, schema, and runner — and public is
// fine: it carries no mutants. The answer key (the private corpus) lives in the
// consumers, never here.
//
// Split so a future language port reimplements only the binding:
//   • WorkbookGraderCore  — the language-neutral contract (no engine).
//   • WorkbookGraderSwift — the swift-property-based binding.
//
// Engine pinned to 1.2.x, inherited by every consumer.
let package = Package(
    name: "pbt-workbook-grader",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WorkbookGraderCore", targets: ["WorkbookGraderCore"]),
        .library(name: "WorkbookGraderSwift", targets: ["WorkbookGraderSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/x-sheep/swift-property-based.git",
                 .upToNextMinor(from: "1.2.0")),
    ],
    targets: [
        .target(name: "WorkbookGraderCore"),
        .testTarget(
            name: "WorkbookGraderCoreTests",
            dependencies: ["WorkbookGraderCore"]
        ),
        .target(
            name: "WorkbookGraderSwift",
            dependencies: [
                "WorkbookGraderCore",
                .product(name: "PropertyBased", package: "swift-property-based"),
            ]
        ),
    ]
)
