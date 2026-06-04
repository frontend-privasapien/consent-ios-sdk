<p align="center">
  <h1 align="center">Privasapien Consent SDK — iOS</h1>
  <p align="center">
    A production-ready SDK for managing user consent, privacy preferences, and regulatory compliance — with a fully customizable, backend-driven UI for iOS.
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/SPM-compatible-orange?style=flat-square&logo=swift" alt="SPM" />
  <img src="https://img.shields.io/badge/platform-iOS-brightgreen?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-5.9+-orange?style=flat-square&logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/iOS-15%2B-blue?style=flat-square&logo=apple" alt="iOS 15+" />
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#ui-modes">UI Modes</a> •
  <a href="#event-listeners">Events</a> •
  <a href="#troubleshooting">Troubleshooting</a>
</p>

---

Built with **Swift**, **SwiftUI**, and **Clean Architecture**. Supports **GDPR**, **DPDP**, and other global privacy regulations out of the box.

---

## Why Privasapien Consent SDK?

Most apps handle consent with hardcoded dialogs or fragile WebViews. When regulations change or your legal team updates the privacy policy, you're stuck pushing an app update.

**Privasapien Consent SDK** solves this with a backend-driven approach — your consent UI, text, and logic are all controlled from the server. No app updates needed.

### Features

- **Backend-driven consent UI** — colors, text, layout, and purposes all configured remotely
- **GDPR & DPDP compliant** — built for global privacy regulations
- **Multi-language support** — switch consent language dynamically from a dropdown
- **Persistent consent state** — dual-layer cache (in-memory + UserDefaults) for instant loads
- **Bottom Sheet & Full Screen modes** — adapts to your UX needs
- **Event listeners** — get notified on submit, toggle, language change, close, and errors
- **SwiftUI-first API** — drop-in views, no UIKit wrappers needed
- **Premium feedback UI** — animated floating toast for success/failure states
- **iPad-responsive** — adaptive layout for larger screens
- **Offline-ready caching** — shows cached consent instantly, refreshes in background

---

## Requirements

| Component | Requirement |
|-----------|-------------|
| iOS | 15.0+ |
| Xcode | 15.0+ |
| Swift | 5.9+ |
| Distribution | Swift Package Manager |

---

## Installation

### Swift Package Manager

#### Xcode

1. Open your project in Xcode
2. Navigate to **File → Add Package Dependencies...**
3. Enter the repository URL:
   ```
   https://github.com/anthropic-consent/consent-sdk-ios.git
   ```
4. Select version rule **Up to Next Major Version** from `1.0.2`
5. Click **Add Package**

#### Package.swift

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/anthropic-consent/consent-sdk-ios.git", from: "1.0.2")
]
```

Then add `ConsentSDK` to your target dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: ["ConsentSDK"]
)
```

---

## Quick Start

### 1. Initialize the SDK

Call this once at app launch:

```swift
import ConsentSDK

@main
struct MyApp: App {
    init() {
        ConsentManager.shared.initialize(
            config: ConsentInitConfig(
                apiUrl: "https://api.your-domain.com/api/v1",
                applicationId: "your-app-id",
                tenantId: "your-tenant-id",
                userIdentifier: "user@example.com",
                modeOfCommunication: "email"
            )
        )
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### 2. Show the Consent UI

```swift
import ConsentSDK

struct ContentView: View {
    @State private var showConsent = false

    var body: some View {
        Button("Manage Privacy") {
            showConsent = true
        }
        .sheet(isPresented: $showConsent) {
            ConsentBottomSheet(onDismiss: { showConsent = false })
        }
    }
}
```

The SDK handles everything — loading states, fetching data, rendering the UI, and submitting consent.

---

## Configuration

All fields for `ConsentInitConfig`:

| Parameter | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `apiUrl` | `String` | ✓ | Base URL of your consent API |
| `applicationId` | `String` | ✓ | Your application UUID |
| `tenantId` | `String` | ✓ | Your tenant UUID |
| `userIdentifier` | `String` | ✓ | User's email or phone |
| `modeOfCommunication` | `String` | ✓ | `"email"` or `"phone"` |
| `introductionMessage` | `String?` | | Message shown above the consent notice |
| `age` | `Int?` | | User's age (enables parental consent flow if < 18) |
| `parentEmail` | `String?` | | Required when `age < 18` |
| `language` | `String` | | Default language. Defaults to `"english"` |

Configuration validates at creation time — invalid inputs throw immediately, not at runtime.

---

## UI Modes

| View | Use Case |
|------|----------|
| `ConsentBottomSheet(onDismiss:)` | Modal bottom sheet — most common for in-app consent |
| `ConsentFullScreen(onDismiss:)` | Full-screen surface — ideal for first-time onboarding |
| `ConsentDialog(onDismiss:)` | Auto-selects mode based on backend config |

All modes share the same ViewModel and render identically. Styling is driven by your backend configuration.

### Bottom Sheet Example

```swift
.sheet(isPresented: $showConsent) {
    ConsentBottomSheet(onDismiss: { showConsent = false })
}
```

### Full Screen Example

```swift
.fullScreenCover(isPresented: $showConsent) {
    ConsentFullScreen(onDismiss: { showConsent = false })
}
```

---

## Event Listeners

Subscribe to consent lifecycle events:

```swift
ConsentManager.shared.initialize(
    config: config,
    listener: ConsentEventListener(
        onConsentSubmitted: { acceptedPurposeIds in
            // User saved their preferences
        },
        onConsentClosed: {
            // User dismissed without saving
        },
        onConsentError: { error in
            // Network or API error
        },
        onLanguageChanged: { languageCode in
            // Language switched
        },
        onPurposeToggled: { purposeId, isSelected in
            // Individual purpose toggled
        }
    )
)
```

All callbacks are optional — implement only what you need.

---

## Data Flow

```
User opens consent → ViewModel.load()
    ├── 1. Check cache (instant UI)
    └── 2. Fetch fresh data (parallel API calls)
            ├── Languages
            ├── Purposes
            ├── Existing consent state
            ├── Notice text
            └── UI configuration
        → Decode → Domain models → Update UI
```

### Caching Strategy

| Layer | Speed | Persistence | Use |
|-------|-------|-------------|-----|
| In-memory | ~0ms | Process lifetime | Instant re-renders |
| UserDefaults | ~5ms | Permanent | Survives app restart |

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| HTTP | URLSession (native) |
| Serialization | Codable |
| Async | Swift Concurrency (async/await) |
| State | ObservableObject + @Published |
| Distribution | Swift Package Manager (XCFramework) |
| Min iOS | 15.0 |

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Package resolution fails | Ensure you have network access and the repository URL is correct |
| Minimum deployment target error | Set your project's iOS deployment target to 15.0 or higher |
| Symbol not found | Clean build folder (Cmd+Shift+K) and rebuild |
| Module not found | Ensure `ConsentSDK` is added to your target's frameworks |
| Initialization failure | Verify your `applicationId` and `tenantId` are valid UUIDs |

### Debug Logging

Enable verbose logging for development:

```swift
ConsentManager.shared.setLogLevel(.verbose)
```

### Support

For technical support, please contact your account representative or visit our developer portal.

---

## License

Copyright © 2024 Privasapien. All rights reserved. See [LICENSE](LICENSE) for details.
