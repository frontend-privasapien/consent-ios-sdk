@_exported import ConsentCore
import SwiftUI
import UIKit

/// The iOS entry point, the counterpart of the Android `ConsentSdk`. Call everything on the main thread; listener
/// callbacks arrive there too.
///
/// ```
/// ConsentSdk.shared.initialize(config: config, listener: self)   // once, e.g. when the app starts
/// ConsentSdk.shared.setUser(user: user)                          // after login (with autoOpen, the flow starts here)
/// ConsentSdk.shared.open()                                       // a "Manage consent" tap: always shows the sheet
/// ConsentSdk.shared.requestOpen()                                // from anywhere: shows only if consent is owed
/// ConsentSdk.shared.clearUser()                                  // on logout
/// ```
///
/// The sheet presents itself over the app's top view controller and dismisses itself. Calling these in the wrong
/// order never crashes the app: the mistake is logged and ignored (D14). `@objc`, so React Native's Objective-C++
/// module can call it too.
@objc(ConsentSdk)
public final class ConsentSdk: NSObject {

    @objc public static let shared = ConsentSdk()

    private var controller: ConsentController?
    private var subscription: ConsentSubscription?
    private var sheet: UIViewController?
    private var watchingApp = false
    private let logger = PlatformLogger()

    private override init() {}

    /// Starts the SDK. Calling it again replaces the previous setup and closes its network client.
    @objc public func initialize(config: ConsentConfig) {
        initialize(config: config, listener: SilentListener())
    }

    /// Starts the SDK and reports what happens to `listener`. Calling it again takes down a sheet on screen.
    @objc public func initialize(config: ConsentConfig, listener: ConsentListener) {
        subscription?.cancel()
        // The sheet on screen draws the old controller, which stops telling it anything once closed. Left up, it
        // would never close, and while locked nobody could get past it.
        dismissSheet()
        controller?.close()

        watchApp()
        let fresh = ConsentController(config: config, listener: listener, platformLogger: logger)
        controller = fresh

        // The sheet appears when the flow decides it should show, and dismisses itself when it is hidden.
        subscription = fresh.observe { [weak self] state in
            if state.visible { self?.showSheet() }
        }
    }

    /// Sets who consent is asked of, after login. With `autoOpen`, the flow starts here.
    @objc public func setUser(user: ConsentUser) {
        guard let controller else { return notInitialised("setUser") }
        controller.setUser(user: user)
    }

    /// On logout: forgets the user and closes the sheet, locked or not.
    @objc public func clearUser() {
        guard let controller else { return notInitialised("clearUser") }
        controller.clearUser()
    }

    /// For a "Manage consent" tap: always shows the sheet.
    @objc public func open() {
        guard let controller else { return notInitialised("open") }
        controller.open(force: true)
    }

    /// For events from anywhere in the app: shows the sheet only when consent is owed.
    @objc public func requestOpen() {
        requestOpen(force: false)
    }

    /// Like `requestOpen()`, and with `force` set it always shows the sheet, like `open()`.
    @objc public func requestOpen(force: Bool) {
        guard let controller else { return notInitialised("requestOpen") }
        controller.open(force: force)
    }

    /// Shows the sheet in another language, for example when the app's own language changes. An open sheet switches
    /// straight away, keeping the user's ticks; later opens ask for `code` too. The server falls back to English when
    /// the notice is not published in `code`, and the SDK's own words follow whatever it served.
    @objc public func setLanguage(code: String) {
        guard let controller else { return notInitialised("setLanguage") }
        controller.setLanguage(code: code)
    }

    // Presents the sheet unless one is up. With no window to present on yet (an auto open after a slow login, with
    // the app still starting or in the background), the next time the app becomes active it is tried again.
    private func showSheet() {
        guard let active = controller, sheet == nil, let host = topViewController() else { return }
        let view = SheetHost(model: SheetModel(controller: active), onGone: { [weak self] in self?.dismissSheet() })
        let vc = UIHostingController(rootView: view)
        // Transparent, so the app shows through behind the sheet, like the Android ConsentActivity.
        vc.modalPresentationStyle = .overFullScreen
        vc.view.backgroundColor = .clear
        sheet = vc
        // Not inside the callback that told us: the host may be in the middle of its own view update.
        DispatchQueue.main.async { host.present(vc, animated: false) }
    }

    private func dismissSheet() {
        sheet?.dismiss(animated: false)
        sheet = nil
    }

    private func watchApp() {
        if watchingApp { return }
        watchingApp = true
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            if self?.controller?.state.visible == true { self?.showSheet() }
        }
    }

    // The screen the sheet goes over: the key window's root, then whatever it already presents on top.
    private func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    // With no controller there is no listener to tell, so the only place to say it is the log.
    private func notInitialised(_ call: String) {
        logger.log(
            level: .warn,
            message: "\(call)() was called before initialize(). Call ConsentSdk.shared.initialize() first, when the app starts."
        )
    }
}

/// The platform log. Core decides what to log and leaves out keys and personal data.
private final class PlatformLogger: NSObject, ConsentLogger {
    func log(level: ConsentLogLevel, message: String) {
        NSLog("ConsentSDK: %@", message)
    }
}

/// For `initialize(config:)`. Swift does not see Kotlin's default methods, so each one is written out.
private final class SilentListener: NSObject, ConsentListener {
    func onSaved(result: ConsentSaved) {}
    func onSkipped(grantedPurposeIds: [String]) {}
    func onClosed() {}
    func onError(error: ConsentError) {}
}

/// The controller's state for SwiftUI. It follows the controller until the sheet goes away.
final class SheetModel: ObservableObject {
    @Published private(set) var state: ConsentState
    let controller: ConsentController
    private var subscription: ConsentSubscription?

    init(controller: ConsentController) {
        self.controller = controller
        state = controller.state
        subscription = controller.observe { [weak self] in self?.state = $0 }
    }

    deinit { subscription?.cancel() }
}
