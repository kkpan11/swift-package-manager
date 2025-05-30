//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2015-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import Foundation

import Basics
@testable import Build
import LLBuildManifest

@_spi(DontAdoptOutsideOfSwiftPMExposedForBenchmarksAndTestsOnly)
import PackageGraph

import PackageModel
import struct SPMBuildCore.BuildParameters

import _InternalBuildTestSupport
@_spi(SwiftPMInternal)
import _InternalTestSupport

import Testing

struct LLBuildManifestBuilderTests {
    @Test
    func createProductCommand() async throws {
        let pkg = AbsolutePath("/pkg")
        let fs = InMemoryFileSystem(
            emptyFiles:
                pkg.appending(components: "Sources", "exe", "main.swift").pathString
        )

        let observability = ObservabilitySystem.makeForTesting()
        let graph = try loadModulesGraph(
            fileSystem: fs,
            manifests: [
                Manifest.createRootManifest(
                    displayName: "Pkg",
                    path: .init(validating: pkg.pathString),
                    targets: [
                        TargetDescription(name: "exe"),
                    ]
                ),
            ],
            observabilityScope: observability.topScope
        )

        // macOS, release build

        var plan = try await mockBuildPlan(
            environment: BuildEnvironment(
                platform: .macOS,
                configuration: .release
            ),
            graph: graph,
            fileSystem: fs,
            observabilityScope: observability.topScope
        )

        var result = try BuildPlanResult(plan: plan)
        var buildProduct = try result.buildProduct(for: "exe")

        var llbuild = LLBuildManifestBuilder(
            plan,
            fileSystem: localFileSystem,
            observabilityScope: observability.topScope
        )
        try llbuild.createProductCommand(buildProduct)

        var basicReleaseCommandNames = [
            AbsolutePath("/path/to/build/\(plan.destinationBuildParameters.triple)/release/exe.product/Objects.LinkFileList").pathString,
            "<exe-\(plan.destinationBuildParameters.triple)-release.exe>",
            "C.exe-\(plan.destinationBuildParameters.triple)-release.exe",
        ]

        #expect(llbuild.manifest.commands.map(\.key).sorted() == basicReleaseCommandNames.sorted())

        // macOS, debug build

        plan = try await mockBuildPlan(
            environment: BuildEnvironment(
                platform: .macOS,
                configuration: .debug
            ),
            graph: graph,
            fileSystem: fs,
            observabilityScope: observability.topScope
        )

        result = try BuildPlanResult(plan: plan)
        buildProduct = try result.buildProduct(for: "exe")

        llbuild = LLBuildManifestBuilder(plan, fileSystem: fs, observabilityScope: observability.topScope)
        try llbuild.createProductCommand(buildProduct)

        let entitlementsCommandName = "C.exe-\(plan.destinationBuildParameters.triple)-debug.exe-entitlements"
        var basicDebugCommandNames = [
            AbsolutePath("/path/to/build/\(plan.destinationBuildParameters.triple)/debug/exe.product/Objects.LinkFileList").pathString,
            "<exe-\(plan.destinationBuildParameters.triple)-debug.exe>",
            "C.exe-\(plan.destinationBuildParameters.triple)-debug.exe",
        ]

        #expect(llbuild.manifest.commands.map(\.key).sorted() == (basicDebugCommandNames + [
            AbsolutePath("/path/to/build/\(plan.destinationBuildParameters.triple)/debug/exe-entitlement.plist").pathString,
            entitlementsCommandName,
        ]).sorted())

        let entitlementsCommand = try #require(
            llbuild.manifest.commands[entitlementsCommandName]?.tool as? ShellTool,
            "unexpected entitlements command type"
        )

        #expect(entitlementsCommand.inputs == [
            .file("/path/to/build/\(plan.destinationBuildParameters.triple)/debug/exe", isMutated: true),
            .file("/path/to/build/\(plan.destinationBuildParameters.triple)/debug/exe-entitlement.plist"),
        ])
        #expect(entitlementsCommand.outputs == [
            .virtual("exe-\(plan.destinationBuildParameters.triple)-debug.exe-CodeSigning"),
        ])

        // Linux, release build

        plan = try await mockBuildPlan(
            environment: BuildEnvironment(
                platform: .linux,
                configuration: .release
            ),
            graph: graph,
            fileSystem: fs,
            observabilityScope: observability.topScope
        )

        result = try BuildPlanResult(plan: plan)
        buildProduct = try result.buildProduct(for: "exe")

        llbuild = LLBuildManifestBuilder(plan, fileSystem: localFileSystem, observabilityScope: observability.topScope)
        try llbuild.createProductCommand(buildProduct)

        basicReleaseCommandNames = [
            AbsolutePath("/path/to/build/\(plan.destinationBuildParameters.triple)/release/exe.product/Objects.LinkFileList").pathString,
            "<exe-\(plan.destinationBuildParameters.triple)-release.exe>",
            "C.exe-\(plan.destinationBuildParameters.triple)-release.exe",
        ]

        #expect(llbuild.manifest.commands.map(\.key).sorted() == basicReleaseCommandNames.sorted())

        // Linux, debug build

        plan = try await mockBuildPlan(
            environment: BuildEnvironment(
                platform: .linux,
                configuration: .debug
            ),
            graph: graph,
            fileSystem: fs,
            observabilityScope: observability.topScope
        )

        result = try BuildPlanResult(plan: plan)
        buildProduct = try result.buildProduct(for: "exe")

        llbuild = LLBuildManifestBuilder(plan, fileSystem: fs, observabilityScope: observability.topScope)
        try llbuild.createProductCommand(buildProduct)

        basicDebugCommandNames = [
            AbsolutePath("/path/to/build/\(plan.destinationBuildParameters.triple)/debug/exe.product/Objects.LinkFileList").pathString,
            "<exe-\(plan.destinationBuildParameters.triple)-debug.exe>",
            "C.exe-\(plan.destinationBuildParameters.triple)-debug.exe",
        ]

        #expect(llbuild.manifest.commands.map(\.key).sorted() == basicDebugCommandNames.sorted())
    }

    /// Verifies that two modules with the same name but different triples don't share same build manifest keys.
    @Test
    func toolsBuildTriple() async throws {
        let (graph, fs, scope) = try macrosPackageGraph()
        let productsTriple = Triple.x86_64MacOS
        let toolsTriple = Triple.arm64Linux

        let plan = try await BuildPlan(
            destinationBuildParameters: mockBuildParameters(
                destination: .target,
                shouldLinkStaticSwiftStdlib: true,
                triple: productsTriple
            ),
            toolsBuildParameters: mockBuildParameters(
                destination: .host,
                triple: toolsTriple
            ),
            graph: graph,
            fileSystem: fs,
            observabilityScope: scope
        )

        let builder = LLBuildManifestBuilder(plan, fileSystem: fs, observabilityScope: scope)
        let manifest = try builder.generateManifest(at: "/manifest")

        #expect(manifest.commands["C.SwiftSyntax-aarch64-unknown-linux-gnu-debug-tool.module"] != nil)
        // Ensure that Objects.LinkFileList is -tool suffixed.
        #expect(manifest.commands[AbsolutePath("/path/to/build/aarch64-unknown-linux-gnu/debug/MMIOMacros-tool.product/Objects.LinkFileList").pathString] != nil)
    }
}
