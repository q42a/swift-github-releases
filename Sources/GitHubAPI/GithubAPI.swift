// SPDX-License-Identifier: MIT
// Copyright 2021-2022 Stephen Larew

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum GitHubReleaseAssetState: String, Codable {
  case uploaded
  case open
}

/// Description of a GitHub Release Asset.
public struct GitHubReleaseAsset: Codable {
  public let id: Int
  public let nodeId: String
  public let url: URL
  public let browserDownloadUrl: URL
  public let name: String
  public let label: String?
  public let state: GitHubReleaseAssetState
  public let contentType: String
  public let size: Int
  public let downloadCount: Int
  public let createdAt: Date
  public let updatedAt: Date
}

/// Description of a GitHub Release.
public struct GitHubRelease: Codable {
  public let id: Int
  public let nodeId: String
  public let url: URL
  public let htmlUrl: URL
  public let assetsUrl: URL
  public let uploadUrl: String
  public let tarballUrl: URL?
  public let zipballUrl: URL?
  public let discussionUrl: URL?
  public let tagName: String
  public let targetCommitish: String
  public let name: String?
  public let body: String?
  public let draft: Bool
  public let prerelease: Bool
  public let createdAt: Date
  public let publishedAt: Date?
  public let assets: [GitHubReleaseAsset]
}

/// Endpoints for the the GitHub Releases API.
private enum GitHubAPIEndpoint: CustomStringConvertible {
  /// GET request returns JSON array of releases
  case listReleases(owner: String, repo: String)
  /// GET request returns JSON dict for latest release
  case latestRelease(owner: String, repo: String)
  /// GET request returns JSON dict for release tag
  case taggedRelease(owner: String, repo: String, tag: String)
  /// GET request returns binary content of release asset
  case getReleaseAsset(owner: String, repo: String, assetId: Int)

  /// URL of GitHub API.
  static let BaseURL = URL(string: "https://api.github.com/")

  var url: URL {
    // NB: `self` should be a relative path.
    return URL(string: self.description, relativeTo: Self.BaseURL)!.absoluteURL
  }

  var description: String {
    switch self {
    case .listReleases(let owner, let repo):
      return "repos/\(owner)/\(repo)/releases"
    case .latestRelease(let owner, let repo):
      return "repos/\(owner)/\(repo)/releases/latest"
    case .taggedRelease(let owner, let repo, let tag):
      return "repos/\(owner)/\(repo)/releases/tags/\(tag)"
    case .getReleaseAsset(let owner, let repo, let assetId):
      return "repos/\(owner)/\(repo)/releases/assets/\(assetId)"
    }
  }
}

/// Error Value
public enum GitHubAPIError: Error {
  /// Request error.
  case Request(url: URL, response: HTTPURLResponse?, error: Error)
  /// Request failed due to rate limiting.
  case RateLimited(url: URL, resetDate: Date, response: HTTPURLResponse)
  /// Wrong status.
  case WrongStatus(response: HTTPURLResponse, expectedStatus: Int)
  /// Response is unacceptable.
  case UnacceptableResponse(response: HTTPURLResponse)
  /// Resource data was uninterpretable.
  case ResourceUninterpretable(url: URL, data: Data, error: Error?)
}

/// Controller to interact with the GitHub Release API.
public final class GitHubAPIController {

  /// The URL session for requests.
  let urlSession: URLSession

  /// The default timeout for requests.
  let requestTimeout: TimeInterval

  public init(requestTimeout: TimeInterval = 60) {
    self.requestTimeout = requestTimeout
    self.urlSession = URLSession(configuration: .default)
  }

  /// Returns a list of releases.
  public func listReleases(
    owner: String,
    repo: String,
    networkServiceType srvType: URLRequest.NetworkServiceType = .default,
    validatingCache: Bool = false
  ) async throws -> [GitHubRelease] {
    return try await getEndpointDecoded(
      .listReleases(owner: owner, repo: repo),
      networkServiceType: srvType,
      validatingCache: validatingCache)
  }

  /// Returns the latest release.
  public func latestRelease(
    owner: String,
    repo: String,
    networkServiceType srvType: URLRequest.NetworkServiceType = .default,
    validatingCache: Bool = false
  ) async throws -> GitHubRelease {
    return try await getEndpointDecoded(
      .latestRelease(owner: owner, repo: repo),
      networkServiceType: srvType,
      validatingCache: validatingCache)
  }

  /// Returns the release for a tag.
  public func taggedRelease(
    owner: String,
    repo: String,
    tag: String,
    networkServiceType srvType: URLRequest.NetworkServiceType = .default,
    validatingCache: Bool = false
  ) async throws -> GitHubRelease {
    return try await getEndpointDecoded(
      .taggedRelease(owner: owner, repo: repo, tag: tag),
      networkServiceType: srvType,
      validatingCache: validatingCache)
  }

  /// Returns the file URL of the release asset.
  public func downloadReleaseAsset(
    _ asset: GitHubReleaseAsset,
    networkServiceType srvType: URLRequest.NetworkServiceType = .default,
    validatingCache: Bool = false
  ) async throws -> URL {
    let url = asset.browserDownloadUrl

    var urlRequest = URLRequest(
      url: url,
      cachePolicy: validatingCache ? .reloadRevalidatingCacheData : .useProtocolCachePolicy,
      timeoutInterval: self.requestTimeout)
    urlRequest.networkServiceType = srvType
    urlRequest.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

    let (resourceUrl, urlResponse) = try await urlSession.download(for: urlRequest)

    let statusCode = 200
    let httpUrlResponse = urlResponse as! HTTPURLResponse
    if httpUrlResponse.statusCode == statusCode {
      return resourceUrl
    } else {
      throw GitHubAPIError.WrongStatus(response: httpUrlResponse, expectedStatus: statusCode)
    }
  }

  private static func checkRateLimited(response: URLResponse?) -> GitHubAPIError? {
    guard let response = response as? HTTPURLResponse else { return nil }
    guard response.statusCode == 403 else { return nil }
    if let resetDateString = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
      let resetTimeInterval = TimeInterval(resetDateString)
    {
      var resetDate = Date(timeIntervalSince1970: resetTimeInterval)
      if resetDate < Date() {
        // Reset date already past? Conservatively assume clock drift and add 5 minutes.
        resetDate = Date(timeIntervalSinceNow: 5 * 60)
      }
      return .RateLimited(url: response.url!, resetDate: resetDate, response: response)
    } else {
      // Missing header or actually forbidden? Try again in an hour.
      return .RateLimited(
        url: response.url!,
        resetDate: Date(timeIntervalSinceNow: TimeInterval(60 * 60)),
        response: response)
    }
  }

  /// Returns the endpoint's decoded response.
  private func getEndpointDecoded<T: Decodable>(
    _ endpoint: GitHubAPIEndpoint,
    networkServiceType srvType: URLRequest.NetworkServiceType,
    validatingCache: Bool
  ) async throws -> T {
    let resourceData = try await getEndpointJSON(
      endpoint, networkServiceType: srvType, validatingCache: validatingCache)

    do {
      let d = JSONDecoder()
      d.dateDecodingStrategy = .iso8601
      d.keyDecodingStrategy = .convertFromSnakeCase
      return try d.decode(T.self, from: resourceData)
    } catch {
      throw GitHubAPIError.ResourceUninterpretable(
        url: endpoint.url, data: resourceData, error: error)
    }
  }

  /// Returns the API endpoint resource data (JSON only).
  private func getEndpointJSON(
    _ endpoint: GitHubAPIEndpoint,
    networkServiceType srvType: URLRequest.NetworkServiceType,
    validatingCache validate: Bool
  ) async throws -> Data {
    let (data, response) = try await getEndpoint(
      endpoint, statusCode: 200, networkServiceType: srvType, validatingCache: validate)
    if let mimeType = response.mimeType, mimeType != "application/json" {
      throw GitHubAPIError.UnacceptableResponse(response: response)
    }
    return data
  }

  /// Returns the API endpoint resource data.
  private func getEndpoint(
    _ endpoint: GitHubAPIEndpoint,
    statusCode: Int,
    acceptHeader: String? = "application/vnd.github.v3+json",
    networkServiceType srvType: URLRequest.NetworkServiceType,
    validatingCache: Bool
  ) async throws -> (Data, HTTPURLResponse) {
    let url = endpoint.url

    var urlRequest = URLRequest(
      url: url,
      cachePolicy: validatingCache ? .reloadRevalidatingCacheData : .useProtocolCachePolicy,
      timeoutInterval: self.requestTimeout)
    urlRequest.networkServiceType = srvType
    if let acceptHeader = acceptHeader {
      urlRequest.setValue(acceptHeader, forHTTPHeaderField: "Accept")
    }

    let (resourceData, urlResponse) = try await urlSession.data(for: urlRequest)

    if let rateLimited = Self.checkRateLimited(response: urlResponse) {
      throw rateLimited
    } else {
      let httpUrlResponse = urlResponse as! HTTPURLResponse
      if httpUrlResponse.statusCode == statusCode {
        return (resourceData, httpUrlResponse)
      } else {
        throw GitHubAPIError.WrongStatus(response: httpUrlResponse, expectedStatus: statusCode)
      }
    }
  }
}
