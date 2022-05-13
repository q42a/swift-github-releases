# GitHub Releases

Open-source libraries and utilities for working with GitHub releases.

## ReleaseManifest

Data structures that describe a release and its assets. It is modeled after
GitHub releases.

## makereleasemanifest

Tool that queries the GitHub API to make a release manifest based on a
repository's releases.

A release manifest is a binary property list containing an array of
`ReleaseManifest.ManifestRelease`.

## ghdownloader

Tool that downloads release assets from GitHub.
