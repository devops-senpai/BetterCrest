import Foundation

/// A WebExtension installed for Servo, unpacked in its own folder: a Firefox
/// add-on (`.xpi`) or a folder holding a `manifest.json`. Servo has no
/// extension runtime, so only an extension's content scripts and styles run,
/// as one user script that applies them to the pages their match patterns
/// name. Background scripts, popups and the `browser` APIs do not run.
struct ServoExtension: Identifiable, Equatable {
    // MARK: - Types

    /// The part of `manifest.json` Servo runs.
    private struct Manifest: Decodable {
        struct ContentScript: Decodable {
            var matches: [String]
            var excludeMatches: [String]?
            var js: [String]?
            var css: [String]?
            var allFrames: Bool?

            enum CodingKeys: String, CodingKey {
                case matches, js, css
                case excludeMatches = "exclude_matches"
                case allFrames = "all_frames"
            }
        }

        var name: String
        var version: String?
        var contentScripts: [ContentScript]?
        var background: AnyDecodable?

        enum CodingKeys: String, CodingKey {
            case name, version, background
            case contentScripts = "content_scripts"
        }
    }

    /// Any JSON value, decoded only to learn that it is there.
    private struct AnyDecodable: Decodable {
        init(from decoder: any Decoder) throws {}
    }

    // MARK: - Variables

    /// The folder the extension is unpacked in, whose name identifies it.
    let folder: URL
    let name: String
    let version: String
    /// The user script that applies the extension's content scripts and
    /// styles, or nil when it has none.
    let userScript: String?
    /// Whether it relies on parts Servo cannot run, such as a background
    /// script.
    let isPartial: Bool

    var id: String { folder.lastPathComponent }

    // MARK: - Initializers

    /// The extension unpacked in `folder`, or nil when it holds no readable
    /// manifest.
    init?(folder: URL) {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")),
            let manifest = try? JSONDecoder().decode(Manifest.self, from: Self.withoutByteOrderMark(data))
        else { return nil }
        self.folder = folder
        name = Self.localized(manifest.name, in: folder)
        version = manifest.version ?? ""
        isPartial = manifest.background != nil
        let parts = (manifest.contentScripts ?? []).compactMap { Self.part(for: $0, in: folder) }
        userScript = parts.isEmpty ? nil : "(function () {\n\(parts.joined(separator: "\n"))\n})();"
    }

    // MARK: - Actions - Scripts

    /// One content script entry as a guarded block: its styles, then its
    /// scripts in one shared scope, as WebExtensions run them, only in pages
    /// its patterns match.
    private static func part(for script: Manifest.ContentScript, in folder: URL) -> String? {
        let styles = (script.css ?? []).compactMap { source(of: $0, in: folder) }
        let scripts = (script.js ?? []).compactMap { source(of: $0, in: folder) }
        guard !styles.isEmpty || !scripts.isEmpty else { return nil }
        let matches = literal(script.matches.compactMap(ServoMatchPattern.init).map(\.expression))
        let excluded = literal((script.excludeMatches ?? []).compactMap(ServoMatchPattern.init).map(\.expression))
        var block = "try { (function () {\n"
        block += "  if (!\(matches).some((p) => new RegExp(p).test(location.href))) return;\n"
        block += "  if (\(excluded).some((p) => new RegExp(p).test(location.href))) return;\n"
        if script.allFrames != true { block += "  if (window.top !== window) return;\n" }
        for style in styles {
            block += "  { const s = document.createElement('style'); s.textContent = \(literal(style));\n"
            block += "    (document.head || document.documentElement).appendChild(s); }\n"
        }
        if !scripts.isEmpty { block += "  (function () {\n\(scripts.joined(separator: "\n;\n"))\n  })();\n" }
        block += "})(); } catch (error) { console.error('Arma extension', error); }"
        return block
    }

    private static func source(of path: String, in folder: URL) -> String? {
        let url = folder.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(folder.standardizedFileURL.path + "/"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return String(decoding: withoutByteOrderMark(data), as: UTF8.self)
    }

    /// `value` as a JavaScript literal.
    private static func literal(_ value: some Encodable) -> String {
        (try? String(decoding: JSONEncoder().encode(value), as: UTF8.self)) ?? "null"
    }

    // MARK: - Actions - Manifest

    private static func withoutByteOrderMark(_ data: Data) -> Data {
        data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data
    }

    /// A `__MSG_name__` manifest value read from the extension's default
    /// locale, English, or the value as it is.
    private static func localized(_ value: String, in folder: URL) -> String {
        guard value.hasPrefix("__MSG_"), value.hasSuffix("__") else { return value }
        let key = String(value.dropFirst(6).dropLast(2))
        let locales = folder.appendingPathComponent("_locales")
        for locale in ["en", "en_US"] {
            let file = locales.appendingPathComponent(locale).appendingPathComponent("messages.json")
            guard let data = try? Data(contentsOf: file),
                let messages = try? JSONSerialization.jsonObject(with: withoutByteOrderMark(data)) as? [String: Any],
                let entry = messages.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame })?.value
                    as? [String: Any],
                let message = entry["message"] as? String
            else { continue }
            return message
        }
        return folder.lastPathComponent
    }
}

/// A WebExtension match pattern, such as `*://*.example.com/path*`, as the
/// regular expression a page's address must match.
struct ServoMatchPattern {
    // MARK: - Variables

    let expression: String

    // MARK: - Initializers

    init?(_ pattern: String) {
        if pattern == "<all_urls>" {
            expression = "^(https?|file|ftp)://"
            return
        }
        guard let schemeEnd = pattern.range(of: "://") else { return nil }
        let scheme = String(pattern[..<schemeEnd.lowerBound])
        let rest = pattern[schemeEnd.upperBound...]
        let slash = rest.firstIndex(of: "/") ?? rest.endIndex
        let host = String(rest[..<slash])
        let path = String(rest[slash...])
        let schemeExpression =
            switch scheme {
            case "*": "https?"
            case "http", "https", "file", "ftp", "ws", "wss": scheme
            default: nil as String?
            }
        guard let schemeExpression else { return nil }
        let hostExpression: String
        if host == "*" {
            hostExpression = "[^/]*"
        } else if host.hasPrefix("*.") {
            hostExpression = "([^/]*\\.)?" + NSRegularExpression.escapedPattern(for: String(host.dropFirst(2)))
        } else {
            hostExpression = NSRegularExpression.escapedPattern(for: host)
        }
        let pathExpression = (path.isEmpty ? "/*" : path)
            .split(separator: "*", omittingEmptySubsequences: false)
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: ".*")
        expression = "^\(schemeExpression)://\(hostExpression)(:\\d+)?\(pathExpression)$"
    }
}
