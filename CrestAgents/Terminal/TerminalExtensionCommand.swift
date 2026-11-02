import Foundation

/// `arma extension`: the extensions each Space runs, in Chromium per Space
/// and in Servo for every Space.
///
/// An extension is named by its id, the start of it, or its name in any case.
enum TerminalExtensionCommand: Codable, Sendable {
    // MARK: - Types

    /// Where an extension to install comes from, as the helper read it.
    enum Source: Codable, Sendable {
        /// A Chrome Web Store listing, by its extension id.
        case webStore(id: String)
        /// A file or folder on this Mac, by its absolute path: a Firefox
        /// add-on (`.xpi`), an unpacked extension's folder, or a `.crx`.
        case file(path: String)
    }

    /// The extensions of `space`, or of every Space; only `engine`'s when
    /// given.
    case list(space: String?, engine: TerminalEngine?)
    /// Installs from `source`: a Web Store extension into `space`, or the
    /// front window's, through the review Arma shows; an add-on or folder
    /// into Servo.
    case install(source: Source, space: String?)
    /// Removes `reference` from `space`, or from every Space that has it.
    case remove(reference: String, space: String?)
    /// Turns `reference` on in `space`, or in every Space that has it.
    case enable(reference: String, space: String?)
    /// Turns `reference` off in `space`, or in every Space that has it.
    case disable(reference: String, space: String?)
    /// What `reference` is, asks for and where it runs.
    case info(reference: String)
}
