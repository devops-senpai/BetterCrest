import CoreImage
import CryptoKit
import Foundation
import ImageIO
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// The pictures Spaces wear behind their sidebars on this device, with how
/// each is placed, and the pictures ready to draw.
///
/// A backdrop is an appearance preference, so it stays on the device rather
/// than in the core: the picture is copied into Arma's data folder and the
/// settings sit beside it. Each picture is decoded once at a size a window
/// can show, and blurred once whenever its blur changes, so drawing it is a
/// static image the window composites like any other.
@Observable
@MainActor
final class BrowserSpaceBackdropStore {
    // MARK: - Types

    /// One Space's picture and how it sits.
    struct Backdrop: Codable, Equatable {
        /// The picture's file in the store's folder.
        var file: String
        var anchor: Anchor = .topLeading
        /// How strongly the picture shows over the window's color, 0 through 1.
        var imageOpacity = 1.0
        /// How strongly the Space's own colors lie over the picture, 0 through 1.
        var tintOpacity = 0.35
        /// How soft the picture is, 0 for sharp through 1 for fully blurred.
        var blur = 0.0
        /// How big the picture is drawn against the window.
        var size: Size = .fill
        /// With the original size, whether the picture grows, keeping its
        /// shape, once the window is wider than it.
        var growsToWidth = false
        /// With the original size, whether the picture grows, keeping its
        /// shape, once the window is taller than it.
        var growsToHeight = false
        /// Whether the picture repeats across the window at the size it is
        /// drawn, rather than once.
        var tiles = false
        /// What the sidebar lays under its rows so they read over the picture.
        var tabBacking = TabBacking()

        init(file: String) {
            self.file = file
        }

        /// Reads a backdrop, giving what an older one never saved its
        /// default.
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            file = try container.decode(String.self, forKey: .file)
            anchor = try container.decodeIfPresent(Anchor.self, forKey: .anchor) ?? .topLeading
            imageOpacity = try container.decodeIfPresent(Double.self, forKey: .imageOpacity) ?? 1
            tintOpacity = try container.decodeIfPresent(Double.self, forKey: .tintOpacity) ?? 0.35
            blur = try container.decodeIfPresent(Double.self, forKey: .blur) ?? 0
            size = try container.decodeIfPresent(Size.self, forKey: .size) ?? .fill
            growsToWidth = try container.decodeIfPresent(Bool.self, forKey: .growsToWidth) ?? false
            growsToHeight = try container.decodeIfPresent(Bool.self, forKey: .growsToHeight) ?? false
            tiles = try container.decodeIfPresent(Bool.self, forKey: .tiles) ?? false
            tabBacking = try container.decodeIfPresent(TabBacking.self, forKey: .tabBacking) ?? TabBacking()
        }

        /// This placement with `other`'s, keeping this one's file.
        func placed(like other: Backdrop) -> Backdrop {
            var placed = other
            placed.file = file
            return placed
        }

        /// The size, in points, the picture of `natural` points is drawn at
        /// in a window of `window` points.
        func drawnSize(of natural: CGSize, in window: CGSize) -> CGSize {
            guard natural.width > 0, natural.height > 0 else { return window }
            let widthScale = window.width / natural.width
            let heightScale = window.height / natural.height
            var scale = size.scale(widthScale, heightScale)
            if size == .original {
                if growsToWidth { scale = max(scale, widthScale) }
                if growsToHeight { scale = max(scale, heightScale) }
            }
            return CGSize(width: natural.width * scale, height: natural.height * scale)
        }
    }

    /// A translucent layer the sidebar lays under its rows, so tabs stay
    /// legible over a busy picture: its reach, its color, how much of the
    /// picture shows through it, and how frosted the picture is behind it.
    struct TabBacking: Codable, Equatable, Sendable {
        /// Where the layer lies.
        var reach: TabBackingReach = .off
        /// The layer's color, or nil for the Space's own color, darkened in a
        /// dark look and lightened in a light one.
        var color: BrandColor?
        /// How strongly the layer shows, 0 through 1.
        var opacity = 0.45
        /// How frosted the picture is behind the layer, 0 for clear through 1.
        var blur = 0.0

        init() {}

        /// Reads a tab backing, giving what an older one never saved its default.
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            reach = try container.decodeIfPresent(TabBackingReach.self, forKey: .reach) ?? .off
            color = try container.decodeIfPresent(BrandColor.self, forKey: .color)
            opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.45
            blur = try container.decodeIfPresent(Double.self, forKey: .blur) ?? 0
        }

        /// The color the layer wears over a Space of `branding` in `scheme`.
        func shownColor(over branding: SpaceBranding, in scheme: ColorScheme) -> BrandColor {
            if let color { return color }
            let channel = scheme == .dark ? 0.0 : 1.0
            return BrandColor(red: channel, green: channel, blue: channel)
                .composited(opacity: 0.45, over: branding.backgroundColor)
        }
    }

    /// Where a tab backing lies: nowhere, under each row, or over the whole
    /// sidebar column.
    struct TabBackingReach: Codable, Hashable, Identifiable, Sendable {
        // MARK: - Static Variables

        static let off = TabBackingReach(name: "off", title: "Off", platesRows: false, coversSidebar: false)
        /// A rounded plate under each tab, folder and pinned row.
        static let rows = TabBackingReach(
            name: "rows", title: "Behind Each Row", platesRows: true, coversSidebar: false)
        /// One panel over the sidebar column, above the picture.
        static let sidebar = TabBackingReach(
            name: "sidebar", title: "Behind the Sidebar", platesRows: false, coversSidebar: true)
        static let all = [off, rows, sidebar]

        // MARK: - Variables

        let name: String
        let title: LocalizedStringResource
        /// Whether each row wears a plate of its own.
        let platesRows: Bool
        /// Whether one panel lies over the whole sidebar column.
        let coversSidebar: Bool

        var id: String { name }

        // MARK: - Initializers

        private init(name: String, title: LocalizedStringResource, platesRows: Bool, coversSidebar: Bool) {
            self.name = name
            self.title = title
            self.platesRows = platesRows
            self.coversSidebar = coversSidebar
        }

        init(from decoder: any Decoder) throws {
            let name = try decoder.singleValueContainer().decode(String.self)
            self = Self.all.first { $0.name == name } ?? .off
        }

        // MARK: - Actions - Coding

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(name)
        }

        static func == (lhs: TabBackingReach, rhs: TabBackingReach) -> Bool { lhs.name == rhs.name }

        func hash(into hasher: inout Hasher) { hasher.combine(name) }
    }

    /// How big a picture is drawn against the window it sits in.
    struct Size: Codable, Hashable, Identifiable, Sendable {
        // MARK: - Static Variables

        /// Covers the whole window, cropping what spills over.
        static let fill = Size(name: "fill", title: "Fill Window") { max($0, $1) }
        /// The picture's own size.
        static let original = Size(name: "original", title: "Original Size") { _, _ in 1 }
        /// As wide as the window.
        static let matchWidth = Size(name: "matchWidth", title: "Match Width") { width, _ in width }
        /// As tall as the window.
        static let matchHeight = Size(name: "matchHeight", title: "Match Height") { _, height in height }
        static let all = [fill, original, matchWidth, matchHeight]

        // MARK: - Variables

        let name: String
        let title: LocalizedStringResource
        /// The scale this size draws at, from the scales that would match the
        /// window's width and its height.
        let scale: @Sendable (_ toWidth: Double, _ toHeight: Double) -> Double

        var id: String { name }

        // MARK: - Initializers

        private init(
            name: String, title: LocalizedStringResource,
            scale: @escaping @Sendable (_ toWidth: Double, _ toHeight: Double) -> Double
        ) {
            self.name = name
            self.title = title
            self.scale = scale
        }

        init(from decoder: any Decoder) throws {
            let name = try decoder.singleValueContainer().decode(String.self)
            self = Self.all.first { $0.name == name } ?? .fill
        }

        // MARK: - Actions - Coding

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(name)
        }

        static func == (lhs: Size, rhs: Size) -> Bool { lhs.name == rhs.name }

        func hash(into hasher: inout Hasher) { hasher.combine(name) }
    }

    /// The corner a picture holds to when it is cropped to the window.
    struct Anchor: Codable, Hashable, Identifiable, Sendable {
        // MARK: - Static Variables

        static let topLeading = Anchor(name: "topLeading", title: "Top Left", isTop: true)
        static let bottomLeading = Anchor(name: "bottomLeading", title: "Bottom Left", isTop: false)
        static let all = [topLeading, bottomLeading]

        // MARK: - Variables

        let name: String
        let title: LocalizedStringResource
        /// Whether the picture keeps its top edge, rather than its bottom.
        let isTop: Bool

        var id: String { name }

        // MARK: - Initializers

        private init(name: String, title: LocalizedStringResource, isTop: Bool) {
            self.name = name
            self.title = title
            self.isTop = isTop
        }

        init(from decoder: any Decoder) throws {
            let name = try decoder.singleValueContainer().decode(String.self)
            self = Self.all.first { $0.name == name } ?? .topLeading
        }

        // MARK: - Actions - Coding

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(name)
        }

        static func == (lhs: Anchor, rhs: Anchor) -> Bool { lhs.name == rhs.name }

        func hash(into hasher: inout Hasher) { hasher.combine(name) }
    }

    // MARK: - Static Variables

    static let shared = BrowserSpaceBackdropStore(directory: defaultDirectory(for: .current))

    /// The longest side a picture is decoded at: enough for a large window
    /// on a Retina display, and far less memory than a camera's original.
    private static let decodedPixelSize = 2_400

    /// The blur radius, in decoded pixels, a blur of one gives.
    private static let maximumBlurRadius = 60.0

    // MARK: - Variables

    private(set) var backdrops: [UUID: Backdrop] = [:]
    private let directory: URL?
    @ObservationIgnored private var decoded: [String: CGImage] = [:]
    @ObservationIgnored private var blurred: [String: (blur: Double, image: CGImage)] = [:]
    @ObservationIgnored private let context = CIContext(options: [.cacheIntermediates: false])

    // MARK: - Initializers

    init(directory: URL?) {
        self.directory = directory
        load()
    }

    /// The installed app's Backdrops folder, or for a review launch one kept
    /// apart from it; a launch that keeps nothing keeps nothing.
    static func defaultDirectory(for environment: BrowserLaunchEnvironment) -> URL? {
        guard
            var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent(ProductIdentity.storageDirectoryName, isDirectory: true)
                .appendingPathComponent("Backdrops", isDirectory: true)
        else { return nil }
        if environment.requiresIsolation {
            guard let isolationID = environment.persistentIsolationID else { return nil }
            let namespace = SHA256.hash(data: Data(isolationID.utf8)).map { String(format: "%02x", $0) }.joined()
            directory = directory.appendingPathComponent("Isolated", isDirectory: true)
                .appendingPathComponent(namespace, isDirectory: true)
        }
        return directory
    }

    // MARK: - Actions - Reading

    func backdrop(for spaceID: UUID) -> Backdrop? {
        backdrops[spaceID]
    }

    /// The size of the Space's picture in pixels as decoded, before any blur
    /// shrinks it, or nil for a Space without one.
    func pixelSize(for spaceID: UUID) -> CGSize? {
        guard let backdrop = backdrops[spaceID], let base = decodedImage(backdrop.file) else { return nil }
        return CGSize(width: base.width, height: base.height)
    }

    /// The Space's picture as the window draws it, decoded and blurred as its
    /// settings say, or nil for a Space without one.
    func image(for spaceID: UUID) -> CGImage? {
        guard let backdrop = backdrops[spaceID], let base = decodedImage(backdrop.file) else { return nil }
        guard backdrop.blur > 0 else { return base }
        if let cached = blurred[backdrop.file], cached.blur == backdrop.blur { return cached.image }
        // A blurred picture shows no detail a smaller copy lacks, so the blur
        // runs on a third of the pixels and the window scales it back up.
        let scale = 1.0 / 3
        let input = CIImage(cgImage: base).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let radius = backdrop.blur * Self.maximumBlurRadius * scale
        let output = input.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: input.extent)
        guard let image = context.createCGImage(output, from: input.extent) else { return base }
        blurred[backdrop.file] = (backdrop.blur, image)
        return image
    }

    // MARK: - Mutators

    /// Copies the picture at `url` into the store as the Space's backdrop,
    /// keeping the placement it had. Throws when the file is not a picture.
    func setImage(at url: URL, for spaceID: UUID) throws {
        guard let directory else { return }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = "\(spaceID.uuidString)-\(UUID().uuidString.prefix(8)).\(url.pathExtension.lowercased())"
        try FileManager.default.copyItem(at: url, to: directory.appendingPathComponent(file))
        if let old = backdrops[spaceID]?.file { removeFile(old) }
        var backdrop = backdrops[spaceID] ?? Backdrop(file: file)
        backdrop.file = file
        backdrops[spaceID] = backdrop
        save()
    }

    /// Makes the picture `data`, a `format` file such as `png`, the Space's
    /// backdrop, placed as `backdrop` says. Throws when it is not a picture.
    func setImage(data: Data, format: String, placed backdrop: Backdrop, for spaceID: UUID) throws {
        guard let directory else { return }
        // The same picture only moves: the file, and its decoded copy, stay.
        if let current = backdrops[spaceID], imageData(for: spaceID)?.data == data {
            if current != current.placed(like: backdrop) {
                backdrops[spaceID] = current.placed(like: backdrop)
                save()
            }
            return
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = "\(spaceID.uuidString)-\(UUID().uuidString.prefix(8)).\(format.lowercased())"
        try data.write(to: directory.appendingPathComponent(file), options: .atomic)
        if let old = backdrops[spaceID]?.file { removeFile(old) }
        var placed = backdrop
        placed.file = file
        backdrops[spaceID] = placed
        save()
    }

    /// The bytes and file extension of the Space's picture, or nil for a
    /// Space without one.
    func imageData(for spaceID: UUID) -> (data: Data, format: String)? {
        guard let file = backdrops[spaceID]?.file, let url = directory?.appendingPathComponent(file),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return (data, url.pathExtension)
    }

    /// Changes how the Space's picture sits.
    func update(_ spaceID: UUID, _ change: (inout Backdrop) -> Void) {
        guard var backdrop = backdrops[spaceID] else { return }
        change(&backdrop)
        backdrops[spaceID] = backdrop
        save()
    }

    func remove(for spaceID: UUID) {
        guard let file = backdrops.removeValue(forKey: spaceID)?.file else { return }
        removeFile(file)
        save()
    }

    private func decodedImage(_ file: String) -> CGImage? {
        if let image = decoded[file] { return image }
        guard let url = directory?.appendingPathComponent(file),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: Self.decodedPixelSize,
                ] as CFDictionary)
        else { return nil }
        decoded[file] = image
        return image
    }

    private func removeFile(_ file: String) {
        decoded[file] = nil
        blurred[file] = nil
        guard let url = directory?.appendingPathComponent(file) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private var settingsFile: URL? {
        directory?.appendingPathComponent("backdrops.json")
    }

    private func load() {
        guard let settingsFile, let data = try? Data(contentsOf: settingsFile),
            let stored = try? JSONDecoder().decode([String: Backdrop].self, from: data)
        else { return }
        backdrops = Dictionary(
            uniqueKeysWithValues: stored.compactMap { key, value in UUID(uuidString: key).map { ($0, value) } })
    }

    private func save() {
        guard let directory, let settingsFile else { return }
        let stored = Dictionary(uniqueKeysWithValues: backdrops.map { ($0.key.uuidString, $0.value) })
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(stored).write(to: settingsFile, options: .atomic)
        } catch {
            DiagnosticLog.themes.notice("Space backdrops were not saved: \(DiagnosticLog.describe(error))")
        }
    }
}
