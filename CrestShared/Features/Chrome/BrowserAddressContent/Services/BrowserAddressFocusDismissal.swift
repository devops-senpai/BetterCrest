import Foundation

enum BrowserAddressFocusDismissal {
    static let notification = Notification.Name(
        "com.senpaimedia.bettercrest.dismiss-address-focus"
    )

    static func dismiss() {
        NotificationCenter.default.post(name: notification, object: nil)
    }
}
