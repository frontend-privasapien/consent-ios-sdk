# Changelog

All notable changes to ConsentSDK will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

---

## v2.0.1

A new SDK with a new API (see the README's "Upgrading from 1.x"). The package URL and the product `ConsentSDK` stay the same.

- The consent sheet is drawn in SwiftUI by the SDK and follows your Privasapien configuration: notice text, purposes, branding, lock and language.
- Entry point `ConsentSdk.shared`: `initialize(config:listener:)`, `setUser`, `clearUser`, `open`, `requestOpen`, `setLanguage`, and the four events `onSaved`, `onSkipped`, `onClosed`, `onError`.
- 23 languages, with right-to-left layout for Urdu, Kashmiri and Sindhi.
- The consent rules are shared with the Android, React Native and Flutter SDKs: the compiled core (`ConsentCore`, about 3.4 MB) is downloaded from Privasapien's servers and checked against the checksum in `Package.swift`.
- Runs on the iOS Simulator on Apple Silicon and Intel Macs.
- Licensed under the Apache License 2.0 (1.x was proprietary).

---

## v1.0.2

- Production binary SPM distribution via AWS S3
- XCFramework hosted remotely with checksum verification
- Updated README with full integration documentation

---

## v1.0.0

- Initial binary SPM setup
- XCFramework distribution via Swift Package Manager
- Consent management core functionality
- ConsentBottomSheet and ConsentFullScreen UI components
- Event listener support for consent lifecycle
- iOS 15+ support
- iOS 15+ support
