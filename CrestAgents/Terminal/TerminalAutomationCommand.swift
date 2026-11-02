import Foundation

/// `arma automation`: whether testing frameworks may drive Arma's Chromium
/// engine over its DevTools port, as Settings › Automation sets it. Changes
/// apply after Arma restarts.
enum TerminalAutomationCommand: Codable, Sendable {
    /// What is set, what this run started with, and how to connect.
    case status
    /// Turns automation on or off, and sets what it reaches when given.
    case set(isOn: Bool?, profile: String?, tabs: String?, port: Int?)
    /// Quits Arma and opens it again, so the settings take effect.
    case restart
}
