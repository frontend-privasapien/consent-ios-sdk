# Changelog

All notable changes to ConsentSDK will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

---

## v2.1.0

`ConsentConfig(...)` takes two new last arguments, `continueUrl:` and `apiVersion:`. The 2.0 form still works and leaves both at nil, so apps written for 2.0 build unchanged (see the README's "Upgrading from 2.0").

- `continueUrl`: your DSR portal. A user who owes nothing and taps "Manage consent" now sees that their consent is already on record, with the purposes they granted, *Update my consent* and *Redirect to DSR portal*, which opens this link. Without it the button only closes the sheet.
- `apiVersion`: `.v3` calls the V3 API, where the user's email or phone is never in a URL and `tenant` is not needed. By default the SDK asks your deployment which API it serves.
- The sheet follows more of your Privasapien configuration: the pages the notice turns on and its landing page, the notice's colours and header style, the actionable level of the detailed notice, and auto opt-in (shown with a tag). The privacy policy page shows each purpose's personal data, channels and basis of processing, and categories fold and unfold.
- A purpose the user has already granted can no longer be switched off in the sheet; it shows a padlock, and the sheet says consent is withdrawn through the DSR portal.
- A `readTimeoutMs` or `submitTimeoutMs` of 0 or less now shows the error card with `onError(.generic)` instead of a "could not reach the server" message.
- The compiled core download is about 5.4 MB (5.0 MB in 2.0.2).

---

## v2.0.2

- The compiled core (`ConsentCore`) is now a static framework: it is linked into your app instead of embedded, so there is nothing to copy into the app bundle. Your app's size does not change; the download is about 5 MB instead of 3.4 MB. The Swift code and the API are unchanged.
- The React Native package (`@privasapien/react-native-consent-sdk` 2.0.2) now uses this package for its iOS half instead of carrying its own copy.

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
