// SPDX-License-Identifier: MIT
// Copyright 2021-2022 Stephen Larew

import Foundation

/// Description of a release asset.
public struct ManifestReleaseAsset {
  public init(gitHubID: Int, url: URL, name: String, label: String?, size: Int, updatedAt: Date) {
    self.gitHubID = gitHubID
    self.url = url
    self.name = name
    self.label = label
    self.size = size
    self.updatedAt = updatedAt
  }

  /// ID of GitHub release asset
  public let gitHubID: Int
  /// URL to download the asset
  public let url: URL
  /// File name of the asset
  public let name: String
  public let label: String?
  /// File size in bytes
  public let size: Int
  /// Date of most recent update
  public let updatedAt: Date
}

extension ManifestReleaseAsset: Codable {}

/// Description of a release.
public struct ManifestRelease {
  public init(
    gitHubID: Int, infoUrl: URL, discussionUrl: URL?, tagName: String, name: String?, body: String?,
    prerelease: Bool, createdAt: Date, publishedAt: Date?, assets: [ManifestReleaseAsset]
  ) {
    self.gitHubID = gitHubID
    self.infoUrl = infoUrl
    self.discussionUrl = discussionUrl
    self.tagName = tagName
    self.name = name
    self.body = body
    self.prerelease = prerelease
    self.createdAt = createdAt
    self.publishedAt = publishedAt
    self.assets = assets
  }

  /// ID of GitHub release
  public let gitHubID: Int
  /// URL of the release
  public let infoUrl: URL
  /// URL of the release discussion
  public let discussionUrl: URL?
  /// Name of the tag
  public let tagName: String
  /// Name of the release
  public let name: String?
  /// Text of the body of the release description
  public let body: String?
  /// True if the release is a prerelease
  public let prerelease: Bool
  /// Date of the commit used for the release
  public let createdAt: Date
  /// Date of publication of the release
  public let publishedAt: Date?
  /// List of assets for the release
  public let assets: [ManifestReleaseAsset]
}

extension ManifestRelease: Codable {}
