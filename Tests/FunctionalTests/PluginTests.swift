//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Basics
import _Concurrency

@_spi(SwiftPMInternal)
@testable import PackageGraph
import PackageLoading
import PackageModel
@testable import SPMBuildCore
import _InternalTestSupport
import Workspace
import XCTest

final class PluginTests: XCTestCase {
    func testUseOfBuildToolPluginTargetByExecutableInSamePackage() async throws {
        try XCTSkipOnWindows(because: "TSCBasic/Path.swift:969: Assertion failed, https://github.com/swiftlang/swift-package-manager/issues/8602")
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("MySourceGenPlugin"), configuration: .Debug, extraArgs: ["--product", "MyLocalTool"])
            XCTAssert(stdout.contains("Linking MySourceGenBuildTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Generating foo.swift from foo.dat"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Linking MyLocalTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build of product 'MyLocalTool' complete!"), "stdout:\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        // Try again with the Swift Build build system
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("MySourceGenPlugin"), configuration: .Debug, extraArgs: ["--product", "MyLocalTool", "--build-system", "swiftbuild"])
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
#endif
    }

    func testUseOfBuildToolPluginTargetNoPreBuildCommands() async throws {
        try XCTSkipOnWindows(because: "TSCBasic/Path.swift:969: Assertion failed, https://github.com/swiftlang/swift-package-manager/issues/8602")
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (_, stderr) = try await executeSwiftTest(fixturePath.appending("MySourceGenPluginNoPreBuildCommands"))
            XCTAssertTrue(stderr.contains("file(s) which are unhandled; explicitly declare them as resources or exclude from the target"), "expected warning not emitted")
        }

        // FIXME develop a test for this warning with the Swift Build build system
    }

    func testUseOfBuildToolPluginProductByExecutableAcrossPackages() async throws {
        try XCTSkipOnWindows(because: "TSCBasic/Path.swift:969: Assertion failed,https://github.com/swiftlang/swift-package-manager/issues/8602")
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("MySourceGenClient"), configuration: .Debug, extraArgs: ["--product", "MyTool"])
            XCTAssert(stdout.contains("Linking MySourceGenBuildTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Generating foo.swift from foo.dat"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Linking MyTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build of product 'MyTool' complete!"), "stdout:\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        // Try again with the Swift Build build system
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("MySourceGenClient"), configuration: .Debug, extraArgs: ["--build-system", "swiftbuild", "--product", "MyTool"])
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
#endif
    }

    func testUseOfPrebuildPluginTargetByExecutableAcrossPackages() async throws {
        try XCTSkipOnWindows(because: "TSCBasic/Path.swift:969: Assertion failed, https://github.com/swiftlang/swift-package-manager/issues/8602")
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("MySourceGenPlugin"), configuration: .Debug, extraArgs: ["--product", "MyOtherLocalTool"])
            XCTAssert(stdout.contains("Compiling MyOtherLocalTool bar.swift"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Compiling MyOtherLocalTool baz.swift"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Linking MyOtherLocalTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build of product 'MyOtherLocalTool' complete!"), "stdout:\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("MySourceGenPlugin"), configuration: .Debug, extraArgs: ["--build-system", "swiftbuild", "--product", "MyOtherLocalTool"])
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
#endif
    }

    func testUseOfPluginWithInternalExecutable() async throws {
        try XCTSkipOnWindows(because: "TSCBasic/Path.swift:969: Assertion failed, https://github.com/swiftlang/swift-package-manager/issues/8602")
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
        
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("ClientOfPluginWithInternalExecutable"))
            XCTAssert(stdout.contains("Compiling PluginExecutable main.swift"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Linking PluginExecutable"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Generating foo.swift from foo.dat"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Compiling RootTarget foo.swift"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Linking RootTarget"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        // Try again with the Swift Build build system
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("ClientOfPluginWithInternalExecutable"), extraArgs: ["--build-system", "swiftbuild"])
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
#endif
    }

    func testInternalExecutableAvailableOnlyToPlugin() async throws {
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            await XCTAssertThrowsCommandExecutionError(try await executeSwiftBuild(fixturePath.appending("InvalidUseOfInternalPluginExecutable")), "Illegally used internal executable") { error in
                XCTAssert(
                    error.stderr.contains("product 'PluginExecutable' required by package 'invaliduseofinternalpluginexecutable' target 'RootTarget' not found in package 'PluginWithInternalExecutable'."), "stderr:\n\(error.stderr)"
                )
            }
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            await XCTAssertThrowsCommandExecutionError(try await executeSwiftBuild(fixturePath.appending("InvalidUseOfInternalPluginExecutable")), "Illegally used internal executable"
) { error in
            }
        }
#endif
    }
    
    func testLocalBuildToolPluginUsingRemoteExecutable() async throws {
        try XCTSkipOnWindows(because: "TSCBasic/Path.swift:969: Assertion failed, https://github.com/swiftlang/swift-package-manager/issues/8602")
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
        
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("LibraryWithLocalBuildToolPluginUsingRemoteTool"))
            XCTAssert(stdout.contains("Compiling MySourceGenBuildTool main.swift"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Linking MySourceGenBuildTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Generating generated.swift from generated.dat"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Compiling MyLibrary generated.swift"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        // Try again with the Swift Build build system
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("LibraryWithLocalBuildToolPluginUsingRemoteTool"), extraArgs: ["--build-system", "swiftbuild"])
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
#endif
    }
    
    func testBuildToolPluginDependencies() async throws {
        try XCTSkipOnWindows(because: "TSCBasic/Path.swift:969: Assertion failed, https://github.com/swiftlang/swift-package-manager/issues/8602")
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
        
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("MyBuildToolPluginDependencies"))
            XCTAssert(stdout.contains("Compiling MySourceGenBuildTool main.swift"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Linking MySourceGenBuildTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Generating foo.swift from foo.dat"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Compiling MyLocalTool foo.swift"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        // Try again with the Swift Build build system
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("MyBuildToolPluginDependencies"), extraArgs: ["--build-system", "swiftbuild"])
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
#endif
    }

    func testContrivedTestCases() async throws {
        try XCTSkipOnWindows(because: "TSCBasic/Path.swift:969: Assertion failed, https://github.com/swiftlang/swift-package-manager/issues/8602")
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("ContrivedTestPlugin"), configuration: .Debug, extraArgs: ["--product", "MyLocalTool"])
            XCTAssert(stdout.contains("Linking MySourceGenBuildTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Generating foo.swift from foo.dat"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Linking MyLocalTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build of product 'MyLocalTool' complete!"), "stdout:\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("ContrivedTestPlugin"), configuration: .Debug, extraArgs: ["--build-system", "swiftbuild", "--product", "MyLocalTool", "--disable-sandbox"])
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
#endif
    }

    func testPluginScriptSandbox() async throws {
        #if !os(macOS)
        try XCTSkipIf(true, "test is only supported on macOS")
        #endif
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("SandboxTesterPlugin"), configuration: .Debug, extraArgs: ["--product", "MyLocalTool"])
            XCTAssert(stdout.contains("Linking MyLocalTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build of product 'MyLocalTool' complete!"), "stdout:\n\(stdout)")
        }

        // Try again with Swift Build build system
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("SandboxTesterPlugin"), configuration: .Debug, extraArgs: ["--build-system", "swiftbuild", "--product", "MyLocalTool"])
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
    }

    func testUseOfVendedBinaryTool() async throws {
        #if !os(macOS)
        try XCTSkipIf(true, "test is only supported on macOS")
        #endif
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("MyBinaryToolPlugin"), configuration: .Debug, extraArgs: ["--product", "MyLocalTool"])
            XCTAssert(stdout.contains("Linking MyLocalTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build of product 'MyLocalTool' complete!"), "stdout:\n\(stdout)")
        }
    }

    func testUseOfBinaryToolVendedAsProduct() async throws {
        #if !os(macOS)
        try XCTSkipIf(true, "test is only supported on macOS")
        #endif
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("BinaryToolProductPlugin"), configuration: .Debug, extraArgs: ["--product", "MyLocalTool"])
            XCTAssert(stdout.contains("Linking MyLocalTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build of product 'MyLocalTool' complete!"), "stdout:\n\(stdout)")
        }
    }

    func testBuildToolWithoutOutputs() async throws {
        try XCTSkipOnWindows(because: "build planning stopped due to build-tool plugin failures, needs investigating")
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        func createPackageUnderTest(packageDir: AbsolutePath, toolsVersion: ToolsVersion) throws {
            let manifestFile = packageDir.appending("Package.swift")
            try localFileSystem.createDirectory(manifestFile.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(
                manifestFile,
                string: """
                // swift-tools-version: \(toolsVersion.description)
                import PackageDescription
                let package = Package(name: "MyPackage",
                    targets: [
                        .target(name: "SomeTarget", plugins: ["Plugin"]),
                        .plugin(name: "Plugin", capability: .buildTool),
                    ])
                """)

            let targetSourceFile = packageDir.appending(components: "Sources", "SomeTarget", "dummy.swift")
            try localFileSystem.createDirectory(targetSourceFile.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(targetSourceFile, string: "")

            let pluginSourceFile = packageDir.appending(components: "Plugins", "Plugin", "plugin.swift")
            try localFileSystem.createDirectory(pluginSourceFile.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(pluginSourceFile, string: """
            import PackagePlugin
            #if os(Android)
            let touchExe = "/system/bin/touch"
            #else
            let touchExe = "/usr/bin/touch"
            #endif

            @main
            struct Plugin: BuildToolPlugin {
                func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
                    return [
                        .buildCommand(
                            displayName: "empty",
                            executable: .init(touchExe),
                            arguments: [context.pluginWorkDirectory.appending("best.txt")],
                            inputFiles: [],
                            outputFiles: []
                        )
                    ]
                }
            }
            """)
        }

        try await testWithTemporaryDirectory { tmpPath in
            let packageDir = tmpPath.appending(components: "MyPackage")
            let pathOfGeneratedFile = packageDir.appending(components: [".build", "plugins", "outputs", "mypackage", "SomeTarget", "destination", "Plugin", "best.txt"])

            try createPackageUnderTest(packageDir: packageDir, toolsVersion: .v5_9)
            let (_, stderr) = try await executeSwiftBuild(packageDir, env: ["SWIFT_DRIVER_SWIFTSCAN_LIB" : "/this/is/a/bad/path"])
            XCTAssertTrue(stderr.contains("warning: Build tool command 'empty' (applied to target 'SomeTarget') does not declare any output files"), "expected warning not emitted")
            XCTAssertFalse(localFileSystem.exists(pathOfGeneratedFile), "plugin generated file unexpectedly exists at \(pathOfGeneratedFile.pathString)")

            try createPackageUnderTest(packageDir: packageDir, toolsVersion: .v6_0)
            let (_, stderr2) = try await executeSwiftBuild(packageDir, env: ["SWIFT_DRIVER_SWIFTSCAN_LIB" : "/this/is/a/bad/path"])
            XCTAssertFalse(stderr2.contains("error:"))
            XCTAssertTrue(localFileSystem.exists(pathOfGeneratedFile), "plugin did not run, generated file does not exist at \(pathOfGeneratedFile.pathString)")
        }
    }

    func testCommandPluginInvocation() async throws {
        try XCTSkipIf(true, "test is disabled because it isn't stable, see rdar://117870608")

        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
        
        // FIXME: This test is getting quite long — we should add some support functionality for creating synthetic plugin tests and factor this out into separate tests.
        try await testWithTemporaryDirectory { tmpPath in
            // Create a sample package with a library target and a plugin. It depends on a sample package.
            let packageDir = tmpPath.appending(components: "MyPackage")
            let manifestFile = packageDir.appending("Package.swift")
            try localFileSystem.createDirectory(manifestFile.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(
                manifestFile,
                string: """
                // swift-tools-version: 5.6
                import PackageDescription
                let package = Package(
                    name: "MyPackage",
                    dependencies: [
                        .package(name: "HelperPackage", path: "VendoredDependencies/HelperPackage")
                    ],
                    targets: [
                        .target(
                            name: "MyLibrary",
                            dependencies: [
                                .product(name: "HelperLibrary", package: "HelperPackage")
                            ]
                        ),
                        .plugin(
                            name: "PluginPrintingInfo",
                            capability: .command(
                                intent: .custom(verb: "print-info", description: "Description of the command"),
                                permissions: [.writeToPackageDirectory(reason: "Reason for wanting to write to package directory")]
                            )
                        ),
                        .plugin(
                            name: "PluginFailingWithError",
                            capability: .command(
                                intent: .custom(verb: "fail-with-error", description: "Sample plugin that throws an error")
                            )
                        ),
                        .plugin(
                            name: "PluginFailingWithoutError",
                            capability: .command(
                                intent: .custom(verb: "fail-without-error", description: "Sample plugin that exits without error")
                            )
                        ),
                        .plugin(
                            name: "NeverendingPlugin",
                            capability: .command(
                                intent: .custom(verb: "neverending-plugin", description: "A plugin that doesn't end running")
                            )
                        ),
                    ]
                )
                """
            )
            let librarySourceFile = packageDir.appending(components: "Sources", "MyLibrary", "library.swift")
            try localFileSystem.createDirectory(librarySourceFile.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(
                librarySourceFile,
                string: """
                public func Foo() { }
                """
            )
            let printingPluginSourceFile = packageDir.appending(components: "Plugins", "PluginPrintingInfo", "plugin.swift")
            try localFileSystem.createDirectory(printingPluginSourceFile.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(
                printingPluginSourceFile,
                string: """
                import PackagePlugin
                @main struct MyCommandPlugin: CommandPlugin {
                    func performCommand(
                        context: PluginContext,
                        arguments: [String]
                    ) throws {
                        // Check the identity of the root packages.
                        print("Root package is \\(context.package.displayName).")

                        // Check that we can find a tool in the toolchain.
                        let swiftc = try context.tool(named: "swiftc")
                        print("Found the swiftc tool at \\(swiftc.path).")
                    }
                }
                """
            )
            let pluginFailingWithErrorSourceFile = packageDir.appending(components: "Plugins", "PluginFailingWithError", "plugin.swift")
            try localFileSystem.createDirectory(pluginFailingWithErrorSourceFile.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(
                pluginFailingWithErrorSourceFile,
                string: """
                import PackagePlugin
                @main struct MyCommandPlugin: CommandPlugin {
                    func performCommand(
                        context: PluginContext,
                        arguments: [String]
                    ) throws {
                        // Print some output that should appear before the error diagnostic.
                        print("This text should appear before the uncaught thrown error.")

                        // Throw an uncaught error that should be reported as a diagnostics.
                        throw "This is the uncaught thrown error."
                    }
                }
                extension String: Error { }
                """
            )
            let pluginFailingWithoutErrorSourceFile = packageDir.appending(components: "Plugins", "PluginFailingWithoutError", "plugin.swift")
            try localFileSystem.createDirectory(pluginFailingWithoutErrorSourceFile.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(
                pluginFailingWithoutErrorSourceFile,
                string: """
                import PackagePlugin
                import Foundation
                @main struct MyCommandPlugin: CommandPlugin {
                    func performCommand(
                        context: PluginContext,
                        arguments: [String]
                    ) throws {
                        // Print some output that should appear before we exit.
                        print("This text should appear before we exit.")

                        // Just exit with an error code without an emitting error.
                        exit(1)
                    }
                }
                extension String: Error { }
                """
            )
            let neverendingPluginSourceFile = packageDir.appending(components: "Plugins", "NeverendingPlugin", "plugin.swift")
            try localFileSystem.createDirectory(neverendingPluginSourceFile.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(
                neverendingPluginSourceFile,
                string: """
                import PackagePlugin
                import Foundation
                @main struct MyCommandPlugin: CommandPlugin {
                    func performCommand(
                        context: PluginContext,
                        arguments: [String]
                    ) throws {
                        // Print some output that should appear before we exit.
                        print("This text should appear before we exit.")

                        // Just exit with an error code without an emitting error.
                        exit(1)
                    }
                }
                extension String: Error { }
                """
            )

            // Create the sample vendored dependency package.
            let library1Path = packageDir.appending(components: "VendoredDependencies", "HelperPackage", "Package.swift")
            try localFileSystem.createDirectory(library1Path.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(
                library1Path,
                string: """
                // swift-tools-version: 5.5
                import PackageDescription
                let package = Package(
                    name: "HelperPackage",
                    products: [
                        .library(
                            name: "HelperLibrary",
                            targets: ["HelperLibrary"]
                        ),
                    ],
                    targets: [
                        .target(
                            name: "HelperLibrary"
                        ),
                    ]
                )
                """
            )

            let library2Path = packageDir.appending(components: "VendoredDependencies", "HelperPackage", "Sources", "HelperLibrary", "library.swift")
            try localFileSystem.createDirectory(library2Path.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(
                library2Path,
                string: """
                public func Bar() { }
                """
            )

            // Load a workspace from the package.
            let observability = ObservabilitySystem.makeForTesting()
            let workspace = try Workspace(
                fileSystem: localFileSystem,
                forRootPackage: packageDir,
                customManifestLoader: ManifestLoader(toolchain: UserToolchain.default),
                delegate: MockWorkspaceDelegate()
            )
            
            // Load the root manifest.
            let rootInput = PackageGraphRootInput(packages: [packageDir], dependencies: [])
            let rootManifests = try await workspace.loadRootManifests(
                packages: rootInput.packages,
                observabilityScope: observability.topScope
            )
            XCTAssert(rootManifests.count == 1, "\(rootManifests)")

            // Load the package graph.
            let packageGraph = try await workspace.loadPackageGraph(
                rootInput: rootInput,
                observabilityScope: observability.topScope
            )
            XCTAssertNoDiagnostics(observability.diagnostics)
            XCTAssert(packageGraph.packages.count == 2, "\(packageGraph.packages)")
            XCTAssert(packageGraph.rootPackages.count == 1, "\(packageGraph.rootPackages)")
            let package = try XCTUnwrap(packageGraph.rootPackages.first)
            
            // Find the regular target in our test package.
            let libraryTarget = try XCTUnwrap(package.modules.map(\.underlying).first{ $0.name == "MyLibrary" } as? SwiftModule)
            XCTAssertEqual(libraryTarget.type, .library)
            
            // Set up a delegate to handle callbacks from the command plugin.
            let delegateQueue = DispatchQueue(label: "plugin-invocation")
            class PluginDelegate: PluginInvocationDelegate {
                let delegateQueue: DispatchQueue
                var diagnostics: [Basics.Diagnostic] = []

                init(delegateQueue: DispatchQueue) {
                    self.delegateQueue = delegateQueue
                }
                
                func pluginCompilationStarted(commandLine: [String], environment: [String: String]) {
                }
                
                func pluginCompilationEnded(result: PluginCompilationResult) {
                }
                    
                func pluginCompilationWasSkipped(cachedResult: PluginCompilationResult) {
                }

                func pluginEmittedOutput(_ data: Data) {
                    // Add each line of emitted output as a `.info` diagnostic.
                    dispatchPrecondition(condition: .onQueue(delegateQueue))
                    let textlines = String(decoding: data, as: UTF8.self).split(whereSeparator: { $0.isNewline })
                    print(textlines.map{ "[TEXT] \($0)" }.joined(separator: "\n"))
                    diagnostics.append(contentsOf: textlines.map{
                        Basics.Diagnostic(severity: .info, message: String($0), metadata: .none)
                    })
                }
                
                func pluginEmittedDiagnostic(_ diagnostic: Basics.Diagnostic) {
                    // Add the diagnostic as-is.
                    dispatchPrecondition(condition: .onQueue(delegateQueue))
                    print("[DIAG] \(diagnostic)")
                    diagnostics.append(diagnostic)
                }

                func pluginEmittedProgress(_ message: String) {}
            }

            // Helper function to invoke a plugin with given input and to check its outputs.
            func testCommand(
                package: ResolvedPackage,
                plugin pluginName: String,
                modules moduleNames: [String],
                arguments: [String],
                toolNamesToPaths: [String: AbsolutePath] = [:],
                file: StaticString = #file,
                line: UInt = #line,
                expectFailure: Bool = false,
                diagnosticsChecker: (DiagnosticsTestResult) throws -> Void
            ) async {
                // Find the named plugin.
                let plugins = package.modules.compactMap{ $0.underlying as? PluginModule }
                guard let plugin = plugins.first(where: { $0.name == pluginName }) else {
                    return XCTFail("There is no plugin target named ‘\(pluginName)’")
                }
                XCTAssertTrue(plugin.type == .plugin, "Target \(plugin) isn’t a plugin")

                // Find the named input targets to the plugin.
                var modules: [ResolvedModule] = []
                for name in moduleNames {
                    guard let module = package.modules.first(where: { $0.underlying.name == name }) else {
                        return XCTFail("There is no target named ‘\(name)’")
                    }
                    XCTAssertTrue(module.type != .plugin, "Target \(module) is a plugin")
                    modules.append(module)
                }

                let pluginDir = tmpPath.appending(components: package.identity.description, plugin.name)
                let delegate = PluginDelegate(delegateQueue: delegateQueue)
                do {
                    let scriptRunner = DefaultPluginScriptRunner(
                        fileSystem: localFileSystem,
                        cacheDir: pluginDir.appending("cache"),
                        toolchain: try UserToolchain.default
                    )

                    let toolSearchDirectories = [try UserToolchain.default.swiftCompilerPath.parentDirectory]
                    let success = try await withCheckedThrowingContinuation { continuation in
                      plugin.invoke(
                        action: .performCommand(package: package, arguments: arguments),
                        buildEnvironment: BuildEnvironment(platform: .macOS, configuration: .debug),
                        scriptRunner: scriptRunner,
                        workingDirectory: package.path,
                        outputDirectory: pluginDir.appending("output"),
                        toolSearchDirectories: toolSearchDirectories,
                        accessibleTools: [:],
                        writableDirectories: [pluginDir.appending("output")],
                        readOnlyDirectories: [package.path],
                        allowNetworkConnections: [],
                        pkgConfigDirectories: [],
                        sdkRootPath: nil,
                        fileSystem: localFileSystem,
                        modulesGraph: packageGraph,
                        observabilityScope: observability.topScope,
                        callbackQueue: delegateQueue,
                        delegate: delegate,
                        completion: {
                          continuation.resume(with: $0)
                        }
                      )
                    }
                    if expectFailure {
                        XCTAssertFalse(success, "expected command to fail, but it succeeded", file: file, line: line)
                    }
                    else {
                        XCTAssertTrue(success, "expected command to succeed, but it failed", file: file, line: line)
                    }
                }
                catch {
                    XCTFail("error \(String(describing: error))", file: file, line: line)
                }
                
                // Check that we didn't end up with any completely empty diagnostics.
                XCTAssertNil(observability.diagnostics.first{ $0.message.isEmpty })

                // Invoke the diagnostics checker for the plugin output.
                testDiagnostics(delegate.diagnostics, problemsOnly: false, file: file, line: line, handler: diagnosticsChecker)
            }

            // Invoke the command plugin that prints out various things it was given, and check them.
            await testCommand(package: package, plugin: "PluginPrintingInfo", modules: ["MyLibrary"], arguments: ["veni", "vidi", "vici"]) { output in
                output.check(diagnostic: .equal("Root package is MyPackage."), severity: .info)
                output.check(diagnostic: .and(.prefix("Found the swiftc tool"), .suffix(".")), severity: .info)
            }

            // Invoke the command plugin that throws an unhandled error at the top level.
            await testCommand(package: package, plugin: "PluginFailingWithError", modules: [], arguments: [], expectFailure: true) { output in
                output.check(diagnostic: .equal("This text should appear before the uncaught thrown error."), severity: .info)
                output.check(diagnostic: .equal("This is the uncaught thrown error."), severity: .error)

            }
            // Invoke the command plugin that exits with code 1 without returning an error.
            await testCommand(package: package, plugin: "PluginFailingWithoutError", modules: [], arguments: [], expectFailure: true) { output in
                output.check(diagnostic: .equal("This text should appear before we exit."), severity: .info)
                output.check(diagnostic: .equal("Plugin ended with exit code 1"), severity: .error)
            }
        }
    }

    func testLocalAndRemoteToolDependencies() async throws {
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins/PluginUsingLocalAndRemoteTool") { path in
            let (stdout, stderr) = try await executeSwiftPackage(path.appending("MyLibrary"), configuration: .Debug, extraArgs: ["plugin", "my-plugin"])
            XCTAssert(stderr.contains("Linking RemoteTool"), "stdout:\n\(stderr)\n\(stdout)")
            XCTAssert(stderr.contains("Linking LocalTool"), "stdout:\n\(stderr)\n\(stdout)")
            XCTAssert(stderr.contains("Linking ImpliedLocalTool"), "stdout:\n\(stderr)\n\(stdout)")
            XCTAssert(stderr.contains("Build of product 'ImpliedLocalTool' complete!"), "stdout:\n\(stderr)\n\(stdout)")
            XCTAssert(stdout.contains("A message from the remote tool."), "stdout:\n\(stderr)\n\(stdout)")
            XCTAssert(stdout.contains("A message from the local tool."), "stdout:\n\(stderr)\n\(stdout)")
            XCTAssert(stdout.contains("A message from the implied local tool."), "stdout:\n\(stderr)\n\(stdout)")
        }
    }

    func testPluginUsageDoesntAffectTestTargetMappings() async throws {
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins/MySourceGenPlugin") { packageDir in
            // Load a workspace from the package.
            let observability = ObservabilitySystem.makeForTesting()
            let workspace = try Workspace(
                fileSystem: localFileSystem,
                forRootPackage: packageDir,
                customManifestLoader: ManifestLoader(toolchain: UserToolchain.default),
                delegate: MockWorkspaceDelegate()
            )

            // Load the root manifest.
            let rootInput = PackageGraphRootInput(packages: [packageDir], dependencies: [])
            let rootManifests = try await workspace.loadRootManifests(
                packages: rootInput.packages,
                observabilityScope: observability.topScope
            )
            XCTAssert(rootManifests.count == 1, "\(rootManifests)")

            // Load the package graph.
            let packageGraph = try await workspace.loadPackageGraph(
                rootInput: rootInput,
                observabilityScope: observability.topScope
            )
            XCTAssertNoDiagnostics(observability.diagnostics)

            // Make sure that the use of plugins doesn't bleed into the use of plugins by tools.
            let testTargetMappings = try packageGraph.computeTestModulesForExecutableModules()
            for (target, testTargets) in testTargetMappings {
                XCTAssertFalse(testTargets.contains{ $0.name == "MySourceGenPluginTests" }, "target: \(target), testTargets: \(testTargets)")
            }
        }
    }

    func testCommandPluginCancellation() async throws {
        try XCTSkipOnWindows(because: "This hangs intermittently on windows in CI", skipSelfHostedCI: true)

        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
        
        try await testWithTemporaryDirectory { (tmpPath: AbsolutePath) -> Void in
            // Create a sample package with a couple of plugins a other targets and products.
            let packageDir = tmpPath.appending(components: "MyPackage")
            try localFileSystem.createDirectory(packageDir, recursive: true)
            try localFileSystem.writeFileContents(
                packageDir.appending(components: "Package.swift"),
                string: """
                // swift-tools-version: 5.6
                import PackageDescription
                let package = Package(
                    name: "MyPackage",
                    products: [
                        .library(
                            name: "MyLibrary",
                            targets: ["MyLibrary"]
                        ),
                    ],
                    targets: [
                        .target(
                            name: "MyLibrary"
                        ),
                        .plugin(
                            name: "NeverendingPlugin",
                            capability: .command(
                                intent: .custom(verb: "neverending-plugin", description: "Help description")
                            )
                        ),
                    ]
                )
                """
            )
            let myLibraryTargetDir = packageDir.appending(components: "Sources", "MyLibrary")
            try localFileSystem.createDirectory(myLibraryTargetDir, recursive: true)
            try localFileSystem.writeFileContents(
                myLibraryTargetDir.appending("library.swift"),
                string: """
                public func GetGreeting() -> String { return "Hello" }
                """
            )
            let neverendingPluginTargetDir = packageDir.appending(components: "Plugins", "NeverendingPlugin")
            try localFileSystem.createDirectory(neverendingPluginTargetDir, recursive: true)
            try localFileSystem.writeFileContents(
                neverendingPluginTargetDir.appending("plugin.swift"),
                string: """
                import PackagePlugin
                import Foundation
                @main struct NeverendingPlugin: CommandPlugin {
                    func performCommand(
                        context: PluginContext,
                        arguments: [String]
                    ) throws {
                        print("pid: \\(ProcessInfo.processInfo.processIdentifier)")
                        while true {
                            Thread.sleep(forTimeInterval: 1.0)
                            print("still here")
                        }
                    }
                }
                """
            )

            // Load a workspace from the package.
            let observability = ObservabilitySystem.makeForTesting()
            let workspace = try Workspace(
                fileSystem: localFileSystem,
                forRootPackage: packageDir,
                customManifestLoader: ManifestLoader(toolchain: UserToolchain.default),
                delegate: MockWorkspaceDelegate()
            )
            
            // Load the root manifest.
            let rootInput = PackageGraphRootInput(packages: [packageDir], dependencies: [])
            let rootManifests = try await workspace.loadRootManifests(
                packages: rootInput.packages,
                observabilityScope: observability.topScope
            )
            XCTAssert(rootManifests.count == 1, "\(rootManifests)")

            // Load the package graph.
            let packageGraph = try await workspace.loadPackageGraph(
                rootInput: rootInput,
                observabilityScope: observability.topScope
            )
            XCTAssertNoDiagnostics(observability.diagnostics)
            XCTAssert(packageGraph.packages.count == 1, "\(packageGraph.packages)")
            XCTAssert(packageGraph.rootPackages.count == 1, "\(packageGraph.rootPackages)")
            let package: ResolvedPackage = try XCTUnwrap(packageGraph.rootPackages.first)
            
            // Find the regular target in our test package.
            let libraryTarget = try XCTUnwrap(
                package.modules
                    .map(\.underlying)
                    .first{ $0.name == "MyLibrary" } as? SwiftModule
            )
            XCTAssertEqual(libraryTarget.type, .library)
            
            // Set up a delegate to handle callbacks from the command plugin.  In particular we want to know the process identifier.
            let delegateQueue = DispatchQueue(label: "plugin-invocation")
            class PluginDelegate: PluginInvocationDelegate {
                let delegateQueue: DispatchQueue
                var diagnostics: [Basics.Diagnostic] = []
                var parsedProcessIdentifier: Int? = .none

                init(delegateQueue: DispatchQueue) {
                    self.delegateQueue = delegateQueue
                }
                
                func pluginCompilationStarted(commandLine: [String], environment: [String: String]) {
                }
                
                func pluginCompilationEnded(result: PluginCompilationResult) {
                }
                    
                func pluginCompilationWasSkipped(cachedResult: PluginCompilationResult) {
                }
                
                func pluginEmittedOutput(_ data: Data) {
                    // Add each line of emitted output as a `.info` diagnostic.
                    dispatchPrecondition(condition: .onQueue(delegateQueue))
                    let textlines = String(decoding: data, as: UTF8.self).split(whereSeparator: { $0.isNewline })
                    diagnostics.append(contentsOf: textlines.map{
                        Basics.Diagnostic(severity: .info, message: String($0), metadata: .none)
                    })
                    
                    // If we don't already have the process identifier, we try to find it.
                    if parsedProcessIdentifier == .none {
                        func parseProcessIdentifier(_ string: String) -> Int? {
                            guard let match = try? NSRegularExpression(pattern: "pid: (\\d+)", options: []).firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.count)) else { return .none }
                            // We have a match, so extract the process identifier.
                            assert(match.numberOfRanges == 2)
                            return Int((string as NSString).substring(with: match.range(at: 1)))
                        }
                        parsedProcessIdentifier = textlines.compactMap{ parseProcessIdentifier(String($0)) }.first
                    }
                }
                
                func pluginEmittedDiagnostic(_ diagnostic: Basics.Diagnostic) {
                    // Add the diagnostic as-is.
                    dispatchPrecondition(condition: .onQueue(delegateQueue))
                    diagnostics.append(diagnostic)
                }

                func pluginEmittedProgress(_ message: String) {}
            }

            // Find the relevant plugin.
            let plugins = package.modules.compactMap { $0.underlying as? PluginModule }
            guard let plugin = plugins.first(where: { $0.name == "NeverendingPlugin" }) else {
                return XCTFail("There is no plugin target named ‘NeverendingPlugin’")
            }
            XCTAssertTrue(plugin.type == .plugin, "Target \(plugin) isn’t a plugin")

            // Run the plugin.
            let pluginDir = tmpPath.appending(components: package.identity.description, plugin.name)
            let scriptRunner = DefaultPluginScriptRunner(
                fileSystem: localFileSystem,
                cacheDir: pluginDir.appending("cache"),
                toolchain: try UserToolchain.default
            )
            let delegate = PluginDelegate(delegateQueue: delegateQueue)
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    // TODO: have invoke natively support task cancellation instead
                    try await withTaskCancellationHandler {
                        _ = try await plugin.invoke(
                            action: .performCommand(package: package, arguments: []),
                            buildEnvironment: BuildEnvironment(platform: .macOS, configuration: .debug),
                            scriptRunner: scriptRunner,
                            workingDirectory: package.path,
                            outputDirectory: pluginDir.appending("output"),
                            toolSearchDirectories: [try UserToolchain.default.swiftCompilerPath.parentDirectory],
                            accessibleTools: [:],
                            writableDirectories: [pluginDir.appending("output")],
                            readOnlyDirectories: [package.path],
                            allowNetworkConnections: [],
                            pkgConfigDirectories: [],
                            sdkRootPath: try UserToolchain.default.sdkRootPath,
                            fileSystem: localFileSystem,
                            modulesGraph: packageGraph,
                            observabilityScope: observability.topScope,
                            callbackQueue: delegateQueue,
                            delegate: delegate
                        )
                    } onCancel: {
                        do {
                            try scriptRunner.cancel(deadline: .now() + .seconds(5))
                        } catch {
                            XCTFail("Cancelling script runner should not fail: \(error)")
                        }
                    }
                }
                group.addTask {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(DispatchTimeInterval.seconds(3).nanoseconds()!))
                    } catch {
                        XCTFail("The plugin should not finish within 3 seconds")
                    }
                }

                try await group.next()


                // At this point we should have parsed out the process identifier. But it's possible we don't always — this is being investigated in rdar://88792829.
                var pid: Int? = .none
                delegateQueue.sync {
                    pid = delegate.parsedProcessIdentifier
                }
                guard let pid else {
                    throw XCTSkip("skipping test because no pid was received from the plugin; being investigated as rdar://88792829\n\(delegate.diagnostics.description)")
                }

                // Check that it's running (we do this by asking for its priority — this only works on some platforms).
                #if os(macOS)
                errno = 0
                getpriority(Int32(PRIO_PROCESS), UInt32(pid))
                XCTAssertEqual(errno, 0, "unexpectedly got errno \(errno) when trying to check process \(pid)")
                #endif

                // Ask the plugin running to cancel all plugins.
                group.cancelAll()

                // Check that it's no longer running (we do this by asking for its priority — this only works on some platforms).
                #if os(macOS)
                errno = 0
                getpriority(Int32(PRIO_PROCESS), UInt32(pid))
                XCTAssertEqual(errno, ESRCH, "unexpectedly got errno \(errno) when trying to check process \(pid)")
                #endif
            }


        }
    }

    func testUnusedPluginProductWarnings() async throws {
        // Test the warnings we get around unused plugin products in package dependencies.
        try await testWithTemporaryDirectory { tmpPath in
            // Create a sample package that uses three packages that vend plugins.
            let packageDir = tmpPath.appending(components: "MyPackage")
            try localFileSystem.createDirectory(packageDir, recursive: true)
            try localFileSystem.writeFileContents(
                packageDir.appending("Package.swift"),
                string: """
                // swift-tools-version: 5.6
                import PackageDescription
                let package = Package(
                    name: "MyPackage",
                    dependencies: [
                        .package(name: "BuildToolPluginPackage", path: "VendoredDependencies/BuildToolPluginPackage"),
                        .package(name: "UnusedBuildToolPluginPackage", path: "VendoredDependencies/UnusedBuildToolPluginPackage"),
                        .package(name: "CommandPluginPackage", path: "VendoredDependencies/CommandPluginPackage")
                    ],
                    targets: [
                        .target(
                            name: "MyLibrary",
                            path: ".",
                            plugins: [
                                .plugin(name: "BuildToolPlugin", package: "BuildToolPluginPackage")
                            ]
                        ),
                    ]
                )
                """
            )
            try localFileSystem.writeFileContents(
                packageDir.appending("Library.swift"),
                string: """
                public var Foo: String
                """
            )

            // Create the depended-upon package that vends a build tool plugin that is used by the main package.
            let buildToolPluginPackageDir = packageDir.appending(components: "VendoredDependencies", "BuildToolPluginPackage")
            try localFileSystem.createDirectory(buildToolPluginPackageDir, recursive: true)
            try localFileSystem.writeFileContents(
                buildToolPluginPackageDir.appending("Package.swift"),
                string: """
                // swift-tools-version: 5.6
                import PackageDescription
                let package = Package(
                    name: "BuildToolPluginPackage",
                    products: [
                        .plugin(
                            name: "BuildToolPlugin",
                            targets: ["BuildToolPlugin"])
                    ],
                    targets: [
                        .plugin(
                            name: "BuildToolPlugin",
                            capability: .buildTool(),
                            path: ".")
                    ]
                )
                """
            )
            try localFileSystem.writeFileContents(
                buildToolPluginPackageDir.appending("Plugin.swift"),
                string: """
                import PackagePlugin
                @main struct MyPlugin: BuildToolPlugin {
                    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
                        return []
                    }
                }
                """
            )

            // Create the depended-upon package that vends a build tool plugin that is not used by the main package.
            let unusedBuildToolPluginPackageDir = packageDir.appending(components: "VendoredDependencies", "UnusedBuildToolPluginPackage")
            try localFileSystem.createDirectory(unusedBuildToolPluginPackageDir, recursive: true)
            try localFileSystem.writeFileContents(
                unusedBuildToolPluginPackageDir.appending("Package.swift"),
                string: """
                // swift-tools-version: 5.6
                import PackageDescription
                let package = Package(
                    name: "UnusedBuildToolPluginPackage",
                    products: [
                        .plugin(
                            name: "UnusedBuildToolPlugin",
                            targets: ["UnusedBuildToolPlugin"])
                    ],
                    targets: [
                        .plugin(
                            name: "UnusedBuildToolPlugin",
                            capability: .buildTool(),
                            path: ".")
                    ]
                )
                """
            )
            try localFileSystem.writeFileContents(
                unusedBuildToolPluginPackageDir.appending("Plugin.swift"),
                string: """
                import PackagePlugin
                @main struct MyPlugin: BuildToolPlugin {
                    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
                        return []
                    }
                }
                """
            )

            // Create the depended-upon package that vends a command plugin.
            let commandPluginPackageDir = packageDir.appending(components: "VendoredDependencies", "CommandPluginPackage")
            try localFileSystem.createDirectory(commandPluginPackageDir, recursive: true)
            try localFileSystem.writeFileContents(
                commandPluginPackageDir.appending("Package.swift"),
                string: """
                // swift-tools-version: 5.6
                import PackageDescription
                let package = Package(
                    name: "CommandPluginPackage",
                    products: [
                        .plugin(
                            name: "CommandPlugin",
                            targets: ["CommandPlugin"])
                    ],
                    targets: [
                        .plugin(
                            name: "CommandPlugin",
                            capability: .command(intent: .custom(verb: "how", description: "why")),
                            path: ".")
                    ]
                )
                """
            )
            try localFileSystem.writeFileContents(
                commandPluginPackageDir.appending("Plugin.swift"),
                string: """
                import PackagePlugin
                @main struct MyPlugin: CommandPlugin {
                    func performCommand(context: PluginContext, targets: [Target], arguments: [String]) throws {
                    }
                }
                """
            )

            // Load a workspace from the package.
            let observability = ObservabilitySystem.makeForTesting()
            let workspace = try Workspace(
                fileSystem: localFileSystem,
                location: .init(forRootPackage: packageDir, fileSystem: localFileSystem),
                customManifestLoader: ManifestLoader(toolchain: UserToolchain.default),
                delegate: MockWorkspaceDelegate()
            )

            // Load the root manifest.
            let rootInput = PackageGraphRootInput(packages: [packageDir], dependencies: [])
            let rootManifests = try await workspace.loadRootManifests(
                packages: rootInput.packages,
                observabilityScope: observability.topScope
            )
            XCTAssert(rootManifests.count == 1, "\(rootManifests)")

            // Load the package graph.
            let packageGraph = try await workspace.loadPackageGraph(
                rootInput: rootInput,
                observabilityScope: observability.topScope
            )
            XCTAssert(packageGraph.packages.count == 4, "\(packageGraph.packages)")
            XCTAssert(packageGraph.rootPackages.count == 1, "\(packageGraph.rootPackages)")

            // Check that we have only a warning about the unused build tool plugin (not about the used one and not about the command plugin).
            testDiagnostics(observability.diagnostics, problemsOnly: true) { result in
                result.checkUnordered(diagnostic: .contains("dependency 'unusedbuildtoolpluginpackage' is not used by any target"), severity: .warning)
            }
        }
    }

    func testSnippetSupport() async throws {
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins") { path in
            let (stdout, stderr) = try await executeSwiftPackage(path.appending("PluginsAndSnippets"), configuration: .Debug, extraArgs: ["do-something"])
            XCTAssert(stdout.contains("type of snippet target: snippet"), "output:\n\(stderr)\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        // Try again with the Swift Build build system
        try await fixture(name: "Miscellaneous/Plugins") { path in
            let (stdout, stderr) = try await executeSwiftPackage(path.appending("PluginsAndSnippets"), configuration: .Debug, extraArgs: ["--build-system", "swiftbuild", "do-something"])
            XCTAssert(stdout.contains("type of snippet target: snippet"), "output:\n\(stderr)\n\(stdout)")
        }
#endif
    }

    func testIncorrectDependencies() async throws {
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins") { path in
            let (stdout, stderr) = try await executeSwiftBuild(path.appending("IncorrectDependencies"), extraArgs: ["--build-tests"])
            XCTAssert(stdout.contains("Build complete!"), "output:\n\(stderr)\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        // Try again with the Swift Build build system
        try await fixture(name: "Miscellaneous/Plugins") { path in
            let (stdout, stderr) = try await executeSwiftBuild(path.appending("IncorrectDependencies"), extraArgs: ["--build-system", "swiftbuild", "--build-tests"])
            XCTAssert(stdout.contains("Build complete!"), "output:\n\(stderr)\n\(stdout)")
        }
#endif
    }

    func testSandboxViolatingBuildToolPluginCommands() async throws {
        #if !os(macOS)
        try XCTSkipIf(true, "sandboxing tests are only supported on macOS")
        #endif
        
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        for buildSystem in ["native"] { // FIXME: enable swiftbuild testing once pre-build plugins are working
            // Check that the build fails with a sandbox violation by default.
            try await fixture(name: "Miscellaneous/Plugins/SandboxViolatingBuildToolPluginCommands") { path in
                await XCTAssertAsyncThrowsError(try await executeSwiftBuild(path.appending("MyLibrary"), configuration: .Debug, extraArgs: ["--build-system", buildSystem])) { error in
                    XCTAssertMatch("\(error)", .contains("You don’t have permission to save the file “generated” in the folder “MyLibrary”."))
                }
            }

            // Check that the build succeeds if we disable the sandbox.
            try await fixture(name: "Miscellaneous/Plugins/SandboxViolatingBuildToolPluginCommands") { path in
                let (stdout, stderr) = try await executeSwiftBuild(path.appending("MyLibrary"), configuration: .Debug, extraArgs: ["--build-system", buildSystem, "--disable-sandbox"])
                XCTAssert(stdout.contains("Compiling MyLibrary foo.swift"), "[STDOUT]\n\(stdout)\n[STDERR]\n\(stderr)\n")
            }
        }
    }

    func testTransitivePluginOnlyDependency() async throws {
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("TransitivePluginOnlyDependency"))
            XCTAssert(stdout.contains("Compiling plugin MyPlugin"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Compiling Library Library.swift"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        // Try again with Swift Build build system
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("TransitivePluginOnlyDependency"), extraArgs: ["--build-system", "swiftbuild"])
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
#endif
    }

    func testMissingPlugin() async throws {
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            do {
                try await executeSwiftBuild(fixturePath.appending("MissingPlugin"))
            } catch SwiftPMError.executionFailure(_, _, let stderr) {
                XCTAssert(stderr.contains("error: 'missingplugin': no plugin named 'NonExistingPlugin' found"), "stderr:\n\(stderr)")
            }
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            do {
                try await executeSwiftBuild(fixturePath.appending("MissingPlugin"), extraArgs: ["--build-system", "swiftbuild"])
            } catch SwiftPMError.executionFailure(_, _, let stderr) {
                XCTAssert(stderr.contains("error: 'missingplugin': no plugin named 'NonExistingPlugin' found"), "stderr:\n\(stderr)")
            }
        }
#endif
    }

    func testPluginCanBeReferencedByProductName() async throws {
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("PluginCanBeReferencedByProductName"))
            XCTAssert(stdout.contains("Compiling plugin MyPlugin"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Compiling PluginCanBeReferencedByProductName gen.swift"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        // Try again with the Swift Build build system
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath.appending("PluginCanBeReferencedByProductName"), extraArgs: ["--build-system", "swiftbuild"])
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
#endif
    }

    func testPluginCanBeAffectedByXBuildToolsParameters() async throws {
        try XCTSkipOnWindows(because: "TSCBasic/Path.swift:969: Assertion failed, https://github.com/swiftlang/swift-package-manager/issues/8602")
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the
        // plugin APIs require).
        try XCTSkipIf(
            !UserToolchain.default.supportsSwiftConcurrency(),
            "skipping because test environment doesn't support concurrency"
        )

        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(
                fixturePath.appending(component: "MySourceGenPlugin"),
                configuration: .Debug,
                extraArgs: ["--product", "MyLocalTool", "-Xbuild-tools-swiftc", "-DUSE_CREATE"]
            )
            XCTAssert(stdout.contains("Linking MySourceGenBuildTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Creating foo.swift from foo.dat"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Linking MyLocalTool"), "stdout:\n\(stdout)")
            XCTAssert(stdout.contains("Build of product 'MyLocalTool' complete!"), "stdout:\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        try await fixture(name: "Miscellaneous/Plugins") { fixturePath in
            let (stdout, stderr) = try await executeSwiftBuild(
                fixturePath.appending(component: "MySourceGenPlugin"),
                configuration: .Debug,
                extraArgs: ["-v", "--product", "MyLocalTool", "-Xbuild-tools-swiftc", "-DUSE_CREATE", "--build-system", "swiftbuild"]
            )
            XCTAssert(stdout.contains("MySourceGenBuildTool-product"), "stdout:\n\(stdout)\nstderr:\n\(stderr)")
            XCTAssert(stderr.contains("Creating foo.swift from foo.dat"), "stdout:\n\(stdout)\nstderr:\n\(stderr)")
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)\nstderr:\n\(stderr)")
        }
#endif
    }

    func testURLBasedPluginAPI() async throws {
        try XCTSkipOnWindows(because: "TSCBasic/Path.swift:969: Assertion failed, https://github.com/swiftlang/swift-package-manager/issues/8602")
        // Only run the test if the environment in which we're running actually supports Swift concurrency (which the plugin APIs require).
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins/MySourceGenPluginUsingURLBasedAPI") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath, configuration: .Debug)
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        // Try again with the Swift Build build system
        try await fixture(name: "Miscellaneous/Plugins/MySourceGenPluginUsingURLBasedAPI") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath, configuration: .Debug, extraArgs: ["--build-system", "swiftbuild"])
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
#endif
    }

    func testDependentPlugins() async throws {
        try XCTSkipIf(!UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")

        try await fixture(name: "Miscellaneous/Plugins/DependentPlugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath)
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }

#if os(macOS) // See https://github.com/swiftlang/swift-package-manager/issues/8416 for errors running build tools on Linux
        try await fixture(name: "Miscellaneous/Plugins/DependentPlugins") { fixturePath in
            let (stdout, _) = try await executeSwiftBuild(fixturePath, extraArgs: ["--build-system", "swiftbuild"])
            XCTAssert(stdout.contains("Build complete!"), "stdout:\n\(stdout)")
        }
#endif
    }
}
