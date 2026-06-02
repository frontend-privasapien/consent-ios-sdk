# ConsentSDK for iOS

A privacy-first consent management SDK for iOS applications. ConsentSDK provides a comprehensive, customizable solution for collecting and managing user consent in compliance with global privacy regulations.

---

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 15.0+          |
| Xcode    | 15.0+          |
| Swift    | 5.9+           |

---

## Installation

### Swift Package Manager

Add ConsentSDK to your project using Swift Package Manager.

#### Xcode

1. Open your project in Xcode.
2. Navigate to **File → Add Package Dependencies...**
3. Enter the repository URL:
   ```
   https://github.com/anthropic-consent/consent-sdk-ios.git
   ```
4. Select the version rule (e.g., **Up to Next Major Version** from `1.0.0`).
5. Click **Add Package**.

#### Package.swift

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/anthropic-consent/consent-sdk-ios.git", from: "1.0.0")
]
```

Then add `ConsentSDK` to your target's dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "ConsentSDK", package: "consent-sdk-ios")
    ]
)
```

---

## Quick Start

### Initialization

Initialize the SDK early in your app lifecycle, typically in `AppDelegate` or your app's entry point:

```swift
import ConsentSDK

@main
struct MyApp: App {
    init() {
        ConsentManager.shared.initialize(
            clientId: "your-client-id",
            environment: .production
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Displaying Consent UI

#### Bottom Sheet

Present a compact consent prompt as a bottom sheet:

```swift
import ConsentSDK

ConsentManager.shared.presentConsentBottomSheet(from: viewController) { result in
    switch result {
    case .accepted(let preferences):
        print("User accepted with preferences: \(preferences)")
    case .declined:
        print("User declined consent")
    case .dismissed:
        print("User dismissed without action")
    }
}
```

#### Full Screen

Present a full-screen consent experience:

```swift
import ConsentSDK

ConsentManager.shared.presentConsentFullScreen(from: viewController) { result in
    // Handle consent result
}
```

---

## Configuration

```swift
let config = ConsentConfiguration(
    clientId: "your-client-id",
    environment: .production,
    theme: .default,
    language: .automatic
)

ConsentManager.shared.initialize(with: config)
```

### Configuration Options

| Parameter     | Type                  | Description                          |
|---------------|-----------------------|--------------------------------------|
| `clientId`    | `String`              | Your unique client identifier        |
| `environment` | `ConsentEnvironment`  | `.production` or `.staging`          |
| `theme`       | `ConsentTheme`        | UI theme customization               |
| `language`    | `ConsentLanguage`     | Language preference (`.automatic` uses device locale) |

---

## Event Listeners

Subscribe to consent lifecycle events:

```swift
ConsentManager.shared.onConsentUpdated { event in
    switch event {
    case .consentGranted(let categories):
        // Handle granted consent categories
        break
    case .consentRevoked(let categories):
        // Handle revoked consent categories
        break
    case .consentExpired:
        // Handle expired consent
        break
    }
}
```

---

## Checking Consent Status

```swift
let status = ConsentManager.shared.consentStatus

if status.hasConsent(for: .analytics) {
    // Analytics consent granted
}

if status.hasConsent(for: .marketing) {
    // Marketing consent granted
}
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Package resolution fails | Ensure you have network access and the repository URL is correct |
| Minimum deployment target error | Set your project's iOS deployment target to 15.0 or higher |
| Symbol not found | Clean build folder (Cmd+Shift+K) and rebuild |
| Initialization failure | Verify your `clientId` is valid and the environment is correctly set |

### Debug Logging

Enable verbose logging for development:

```swift
ConsentManager.shared.setLogLevel(.verbose)
```

### Support

For technical support, please contact your account representative or visit our developer portal.

---

## License

Copyright © 2024. All rights reserved. See [LICENSE](LICENSE) for details.
