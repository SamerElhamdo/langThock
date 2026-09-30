import SwiftUI
import AppKit

/// First-run explanation for the one permission LangThock needs.
///
/// Accessibility is required because the keyboard monitor is an *active* CGEvent tap (it must be able to
/// swallow keys for Cleaning Mode). No Input Monitoring / Screen Recording / Notifications / network access is needed,
/// and reading the current Input Source needs no permission at all.
struct PermissionOnboardingView: View {
    let onOpenSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            Text(LangL10n.permissionTitle)
                .font(.system(size: 17, weight: .semibold))
            Text(LangL10n.permissionBody)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(LangL10n.openSystemSettings, action: onOpenSettings)
                .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 380)
    }
}

enum PermissionOnboarding {
    private static var window: NSWindow?
    
    static func show() {
        guard window == nil else { return }
        let view = PermissionOnboardingView {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!)
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = AppInfoHelper.appName
        w.contentView = NSHostingView(rootView: view)
        w.isReleasedWhenClosed = false
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }
    
    static func dismiss() {
        window?.close()
        window = nil
    }
}
