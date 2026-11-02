import SwiftUI

/// The tile behind the banner: a light field by day, a dark one at night.
struct CrestStartPageMarkPalette {
    let background: Color

    init(colorScheme: ColorScheme) {
        background =
            colorScheme == .dark
            ? Color(red: 0.082, green: 0.125, blue: 0.169)
            : Color(red: 0.969, green: 0.965, blue: 0.949)
    }
}
