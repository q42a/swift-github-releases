// SPDX-License-Identifier: MIT
// Copyright 2021-2022 Stephen Larew

import ArgumentParser
import Foundation
import GitHubAPI
import ReleaseManifest

@main
struct MakeReleaseManifest: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "makereleasemanifest",
    abstract: "Make a release manifest.")

  #if !os(Linux)
    @Flag
    var nocompression = false
  #endif
  @Option
  var owner: String
  @Option
  var repo: String

  @Argument
  var output: String = "release-manifest"

  func run() async throws {
    let c = GitHubAPIController()
    let releases = try await c.listReleases(owner: owner, repo: repo)
    writeManifest(convertToManifest(releases))
  }

  private func convertToManifest(_ releases: [GitHubRelease]) -> [ManifestRelease] {
    releases.map { r in
      let a = r.assets.map { a in
        ManifestReleaseAsset(
          gitHubID: a.id, url: a.browserDownloadUrl, name: a.name, label: a.label, size: a.size,
          updatedAt: a.updatedAt)
      }
      return ManifestRelease(
        gitHubID: r.id, infoUrl: r.htmlUrl, discussionUrl: r.discussionUrl, tagName: r.tagName,
        name: r.name, body: r.body, prerelease: r.prerelease, createdAt: r.createdAt,
        publishedAt: r.publishedAt, assets: a)
    }
  }

  private func writeManifest(_ releases: [ManifestRelease]) {
    let e = PropertyListEncoder()
    e.outputFormat = .binary
    do {
      var data = try e.encode(releases)
      #if !os(Linux)
        if !self.nocompression {
          data = try NSData(data: data).compressed(using: .lzfse) as Data
        }
      #endif
      var url = URL(fileURLWithPath: self.output)
      url.deletePathExtension()
      #if os(Linux)
        let ext = "plist"
      #else
        let ext = self.nocompression ? "plist" : "bin"
      #endif
      url.appendPathExtension(ext)
      try data.write(to: url)
    } catch {
      Self.exit(withError: error)
    }
  }
}
