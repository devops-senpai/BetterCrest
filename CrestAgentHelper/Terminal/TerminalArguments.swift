import Foundation

/// The words after `arma <section>`: an action, the values it names in order,
/// and its `--options`. An option takes the word after it as its value unless
/// it is one of the switches the action declares, which take none.
struct TerminalArguments {
    // MARK: - Types

    /// Why the words made no command; the helper prints it with the
    /// section's usage.
    struct Problem: Error {
        let message: String
    }

    // MARK: - Variables

    private(set) var positionals: [String]
    private var options: [String: String]
    private var switches: Set<String>

    // MARK: - Initializers

    /// Reads `words`, where each of `switches` stands alone and every other
    /// `--option` takes a value.
    init(_ words: [String], switches: Set<String> = []) throws(Problem) {
        var positionals: [String] = []
        var options: [String: String] = [:]
        var present: Set<String> = []
        var index = words.startIndex
        while index < words.endIndex {
            let word = words[index]
            if word == "--" {
                positionals += words[(index + 1)...]
                break
            }
            if word.hasPrefix("--"), word.count > 2 {
                var name = String(word.dropFirst(2))
                var value: String?
                if let equals = name.firstIndex(of: "=") {
                    value = String(name[name.index(after: equals)...])
                    name = String(name[..<equals])
                }
                if switches.contains(name) {
                    present.insert(name)
                } else if let value {
                    options[name] = value
                } else {
                    index += 1
                    guard index < words.endIndex else { throw Problem(message: "--\(name) needs a value.") }
                    options[name] = words[index]
                }
            } else {
                positionals.append(word)
            }
            index += 1
        }
        self.positionals = positionals
        self.options = options
        self.switches = present
    }

    // MARK: - Actions - Reading

    /// Takes the next value in order, named `name` in a problem.
    mutating func take(_ name: String) throws(Problem) -> String {
        guard !positionals.isEmpty else { throw Problem(message: "Give \(name).") }
        return positionals.removeFirst()
    }

    /// Takes the next value in order, when there is one.
    mutating func takeIfPresent() -> String? {
        positionals.isEmpty ? nil : positionals.removeFirst()
    }

    /// The value of `--name`, or nil.
    func option(_ name: String) -> String? {
        options[name]
    }

    /// Whether switch `--name` was given.
    func has(_ name: String) -> Bool {
        switches.contains(name)
    }

    /// The value of `--name` as a number, or nil when absent.
    func number(_ name: String) throws(Problem) -> Double? {
        guard let text = options[name] else { return nil }
        guard let value = Double(text) else { throw Problem(message: "--\(name) takes a number, not '\(text)'.") }
        return value
    }

    /// `text` as a number, named `name` in a problem.
    static func number(_ text: String, for name: String) throws(Problem) -> Double {
        guard let value = Double(text) else { throw Problem(message: "\(name) is a number, not '\(text)'.") }
        return value
    }

    /// `text` as one of `Value`'s cases, by its raw value.
    static func choice<Value: RawRepresentable & CaseIterable>(
        _ text: String, as _: Value.Type, for name: String
    ) throws(Problem) -> Value where Value.RawValue == String {
        guard let value = Value(rawValue: text.lowercased()) else {
            let names = Value.allCases.map(\.rawValue).joined(separator: ", ")
            throw Problem(message: "\(name) is one of \(names), not '\(text)'.")
        }
        return value
    }

    /// Refuses values left over after the action read what it takes.
    func finish() throws(Problem) {
        guard positionals.isEmpty else {
            throw Problem(message: "Unexpected '\(positionals.joined(separator: " "))'.")
        }
    }
}
