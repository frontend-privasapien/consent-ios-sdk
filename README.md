# Privasapien Consent SDK for iOS

Shows Privasapien's consent sheet in your iOS app and records the user's consent with your Privasapien account. The notice text, purposes, branding and languages all come from your Privasapien configuration, so changing them needs no app update.

## Requirements

- iOS 15 or newer.
- Xcode 15 or newer (Swift 5.9).
- Your app's settings from Privasapien: API base URL, app key, application id, and tenant (needed on the V2 API only).

## Install

In Xcode: **File → Add Package Dependencies…**, enter

```
https://github.com/frontend-privasapien/consent-ios-sdk
```

and choose **Up to Next Major Version** from `2.1.0`. Add the **ConsentSDK** product to your app target.

Or in a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/frontend-privasapien/consent-ios-sdk", from: "2.1.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [.product(name: "ConsentSDK", package: "consent-ios-sdk")]),
]
```

The package compiles the SDK's Swift code and downloads its compiled core (about 5 MB) from Privasapien's servers. The core is a static framework, linked into your app, so there is nothing to embed. Xcode checks the download against the checksum in `Package.swift`.

## Use

```swift
import ConsentSDK

final class ConsentEvents: NSObject, ConsentListener {
    func onSaved(result: ConsentSaved) { /* consent was recorded: gate features on this */ }
    func onSkipped(grantedPurposeIds: [String]) { /* nothing was owed, so the sheet did not open */ }
    func onClosed() { /* the sheet closed (not a consent signal) */ }
    func onError(error: ConsentError) { /* not found, unauthorized, offline, generic, parent email required */ }
}

let events = ConsentEvents()   // keep a strong reference

// Once, when the app starts. Swift does not see default values here, so every field is passed.
let config = ConsentConfig(
    apiBaseUrl: "https://…",        // from your Privasapien account
    appKey: "…",
    applicationId: "…",
    tenant: "…",
    language: "en",
    autoOpen: true,                 // open the sheet by itself when consent is owed
    skipIfAlreadyConsented: true,
    blockUntilConsented: false,
    readTimeoutMs: 15_000,
    submitTimeoutMs: 30_000,
    logLevel: .error,
    logger: nil,
    continueUrl: "https://…",       // your DSR portal, opened by "Redirect to DSR portal"; nil only closes the sheet
    apiVersion: nil                 // nil asks your deployment which API it serves; behind an API gateway, pass .v3
)
ConsentSdk.shared.initialize(config: config, listener: events)

// After login. With autoOpen, the consent flow starts here.
ConsentSdk.shared.setUser(user: ConsentUser(
    identifier: "user@example.com", identifierType: .email,
    uniqueId: nil, uniqueIdType: nil, age: nil, parentEmail: nil
))

ConsentSdk.shared.open()        // a "Manage consent" button: always shows the sheet
ConsentSdk.shared.clearUser()   // on logout: forgets the user and closes the sheet
```

The sheet presents itself over your app's top view controller and dismisses itself. Call the SDK on the main thread; listener callbacks arrive there too. A call made before `initialize`, or in the wrong order, is logged and ignored: it never crashes your app.

| Call | What it does |
|---|---|
| `initialize(config:listener:)` | Starts the SDK. Call once at startup; calling again replaces the setup. |
| `setUser(user:)` | Sets who consent is asked of. With `autoOpen`, the flow starts here. |
| `clearUser()` | Forgets the user and closes the sheet. |
| `open()` | Always shows the sheet. |
| `requestOpen()` / `requestOpen(force:)` | Shows the sheet only when consent is owed, or always with `force: true`. |
| `setLanguage(code:)` | Shows the sheet in another language, for example `"hi"`. |

`ConsentUser` can also carry `uniqueId` and `uniqueIdType` (your own customer key), and `age` with `parentEmail` (required when `age` is under 18). The sheet is available in 23 languages, including English, Hindi and the other scheduled languages of India, with right-to-left layout for Urdu, Kashmiri and Sindhi. The SDK's version is `ConsentSdkInfo.shared.VERSION`; include it when you report a problem.

## Upgrading from 2.0

Apps written for 2.0 build unchanged: the 2.0 `ConsentConfig(...)` still works and leaves both new settings at nil. To use them, add two last arguments:

- `continueUrl`: your DSR portal (an http or https link). *Redirect to DSR portal* on the "already on record" screen opens it after the sheet closes. With nil the button only closes the sheet.
- `apiVersion`: `.v3` calls the V3 API, which keeps the user's email or phone out of every URL and needs no `tenant`; `.v2` pins V2. With nil the SDK asks your deployment once and uses V2 when it cannot tell. Behind an API gateway, pass `.v3`.

## Upgrading from 1.x

Version 2 is a new SDK. The package URL and the product name `ConsentSDK` stay the same, but the API is different:

- Start with `ConsentSdk.shared.initialize(config:listener:)` and a `ConsentConfig`, then `setUser`, `open` and `clearUser`, as above.
- The sheet is drawn by the SDK and follows your Privasapien configuration; there are no UI modes to choose.
- An app that asks for `from: "1.0.2"` (Up to Next Major) stays on 1.x until you change it to `2.1.0`.

## Other platforms

- **Android:** `com.privasapien:consent-sdk` on Maven Central.
- **React Native and Expo:** `@privasapien/react-native-consent-sdk` on npm.

## License

Apache License 2.0. See [LICENSE](LICENSE).
