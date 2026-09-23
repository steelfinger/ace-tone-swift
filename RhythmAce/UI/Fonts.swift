import SwiftUI

extension Font {
    static func tinosBoldItalic(_ size: CGFloat) -> Font { .custom("Tinos-BoldItalic", fixedSize: size) }
    static func stardosStencil(_ size: CGFloat) -> Font { .custom("StardosStencil-Bold", fixedSize: size) }
    static func bebasNeue(_ size: CGFloat) -> Font { .custom("BebasNeue-Regular", fixedSize: size) }
    static func oswald(_ size: CGFloat) -> Font { .custom("Oswald-Bold", fixedSize: size) }
}

extension Color {
    static let ink = Color(red: 0x22 / 255, green: 0x22 / 255, blue: 0x22 / 255)
    static let ink2 = Color(red: 0x2a / 255, green: 0x2a / 255, blue: 0x2a / 255)
    static let rule = Color(red: 0x33 / 255, green: 0x33 / 255, blue: 0x33 / 255)
}
