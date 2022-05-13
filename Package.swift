// swift-tools-version: 5.6
// SPDX-License-Identifier: MIT
// Copyright 2021-2022 Stephen Larew

import PackageDescription

let package = Package(
  name: "swift-github-releases",
  platforms: [.macOS(.v12)],
  products: [
    .library(name: "GitHubAPI", targets: ["GitHubAPI"]),
    .library(name: "ReleaseManifest", targets: ["ReleaseManifest"]),
    .executable(name: "makereleasemanifest", targets: ["makereleasemanifest"]),
    .executable(name: "ghdownloader", targets: ["ghdownloader"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.2")
  ],
  targets: [
    .target(name: "GitHubAPI"),
    .target(
      name: "ReleaseManifest",
      dependencies: [
        .target(name: "GitHubAPI")
      ]),
    .executableTarget(
      name: "makereleasemanifest",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .target(name: "ReleaseManifest"),
        .target(name: "GitHubAPI"),
      ]),
    .executableTarget(
      name: "ghdownloader",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .target(name: "GitHubAPI"),
      ]),
  ]
)
