// SPDX-License-Identifier: MIT
// Copyright 2021-2022 Stephen Larew

import ArgumentParser
import Foundation
import GitHubAPI

@main
struct ghdownloader: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "ghdownloader",
    abstract: "Download things from GitHub.")

  @Option
  var owner: String
  @Option
  var repo: String
  @Option
  var tag: String?
  @Option
  var name: String

  @Argument(transform: { URL(fileURLWithPath: $0) })
  var output: URL? = nil

  enum Error: String, CustomStringConvertible, Swift.Error {
    case nameNotFound = "Named release asset does not exist."
    var description: String { self.rawValue }
  }

  func run() async throws {
    let c = GitHubAPIController()
    let release: GitHubRelease
    if let tag = tag {
      release = try await c.taggedRelease(owner: owner, repo: repo, tag: tag)
    } else {
      release = try await c.latestRelease(owner: owner, repo: repo)
    }
    guard let asset = release.assets.first(where: { $0.name == name }) else {
      throw Error.nameNotFound
    }
    let url = try await c.downloadReleaseAsset(asset)
    let output = self.output ?? URL(fileURLWithPath: name)
    try FileManager.default.moveItem(at: url, to: output)
  }
}
