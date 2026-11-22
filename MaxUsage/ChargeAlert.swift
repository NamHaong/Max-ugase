import Foundation
import UserNotifications

enum ChargeAlert {
    private static var fired = false

    static func check(level: Double, charging: Bool, threshold: Int) {
        guard charging else { fired = false; return }
        guard Int(level) >= threshold, !fired else { return }
        fired = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let c = UNMutableNotificationContent()
            c.title = "Pin đã đạt \(Int(level))%"
            c.body = "Nên rút sạc để bảo vệ pin."
            c.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "chargeAlert", content: c, trigger: nil))
        }
    }
}
