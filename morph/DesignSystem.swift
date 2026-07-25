import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Morph Design System
// Dark athletic aesthetic: near-black base, electric cyan accent, warm off-white text

// MARK: - Theme
enum MorphTheme {
    static let storageKey = "morph_appearance"

    static var isLight: Bool {
        UserDefaults.standard.string(forKey: storageKey) == "light"
    }

    static var colorScheme: ColorScheme { isLight ? .light : .dark }
}

struct MorphColors {
    private static var light: Bool { MorphTheme.isLight }

    // Backgrounds
    static var background: Color   { light ? Color(hex: "#F4F4F6") : Color(hex: "#0A0A0F") }
    static var surface: Color      { light ? Color(hex: "#FFFFFF") : Color(hex: "#111118") }
    static var surfaceHigh: Color  { light ? Color(hex: "#FAFAFC") : Color(hex: "#1A1A24") }
    static var border: Color       { light ? Color(hex: "#E3E3EA") : Color(hex: "#2A2A3A") }

    // Accent — electric cyan (darker teal in light mode for contrast)
    static var accent: Color       { light ? Color(hex: "#0AA390") : Color(hex: "#00E5CC") }
    static var accentDim: Color    { accent.opacity(light ? 0.12 : 0.15) }
    static var accentGlow: Color   { accent.opacity(light ? 0.22 : 0.3) }

    // Text
    static var textPrimary: Color   { light ? Color(hex: "#16161D") : Color(hex: "#F0EDE8") }
    static var textSecondary: Color { light ? Color(hex: "#5C5C6A") : Color(hex: "#8A8A9A") }
    static var textTertiary: Color  { light ? Color(hex: "#A0A0AC") : Color(hex: "#4A4A5A") }

    // Semantic
    static var success: Color      { light ? Color(hex: "#16A34A") : Color(hex: "#22C55E") }
    static var warning: Color      { light ? Color(hex: "#D97706") : Color(hex: "#F59E0B") }
    static var destructive: Color  { light ? Color(hex: "#DC2626") : Color(hex: "#EF4444") }

    // Score gradient (1→10)
    static func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0..<4:  return light ? Color(hex: "#DC2626") : Color(hex: "#EF4444")
        case 4..<6:  return light ? Color(hex: "#D97706") : Color(hex: "#F59E0B")
        case 6..<8:  return light ? Color(hex: "#65A30D") : Color(hex: "#84CC16")
        default:     return light ? Color(hex: "#16A34A") : Color(hex: "#22C55E")
        }
    }
}

struct MorphFonts {
    // Display: tight tracking, heavy weight for numbers and headers
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default)
    }
    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
}

struct MorphSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

struct MorphCorners {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let pill: CGFloat = 100
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Reusable View Modifiers
struct MorphCardStyle: ViewModifier {
    var elevated: Bool = false
    func body(content: Content) -> some View {
        content
            .background(elevated ? MorphColors.surfaceHigh : MorphColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: MorphCorners.lg))
            .overlay(
                RoundedRectangle(cornerRadius: MorphCorners.lg)
                    .stroke(MorphColors.border, lineWidth: 1)
            )
    }
}

extension View {
    func morphCard(elevated: Bool = false) -> some View {
        modifier(MorphCardStyle(elevated: elevated))
    }
}

// MARK: - Haptics
enum Haptics {
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    static func error() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Animated Score Ring
struct ScoreRing: View {
    let score: Double
    var size: CGFloat = 88
    var lineWidth: CGFloat = 6
    var fontSize: CGFloat = 26

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(MorphColors.border, lineWidth: lineWidth)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    MorphColors.scoreColor(score),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(String(format: "%.1f", score))
                    .font(MorphFonts.display(fontSize))
                    .foregroundColor(MorphColors.textPrimary)
                Text("/ 10")
                    .font(MorphFonts.caption(fontSize * 0.38))
                    .foregroundColor(MorphColors.textTertiary)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) {
                animatedProgress = score / 10
            }
        }
    }
}

// MARK: - Weight Units
enum WeightUnit: String, CaseIterable {
    case kg
    case lbs

    var label: String { rawValue.uppercased() }

    func fromKg(_ kg: Double) -> Double {
        self == .kg ? kg : kg * 2.20462
    }
    func toKg(_ value: Double) -> Double {
        self == .kg ? value : value / 2.20462
    }
    func format(_ kg: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f %@", fromKg(kg), rawValue)
    }
}

struct WeightFormat {
    static let storageKey = "morph_weight_unit"

    static var current: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "kg") ?? .kg
    }

    static func height(_ cm: Double, unit: WeightUnit) -> String {
        if unit == .kg { return String(format: "%.0f cm", cm) }
        let totalInches = cm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.rounded()) % 12
        return "\(feet)'\(inches)\""
    }
}

// MARK: - Unit-Aware Weight Slider
struct WeightSlider: View {
    @Binding var weightKg: Double
    let unit: WeightUnit

    private var displayBinding: Binding<Double> {
        Binding(
            get: { unit.fromKg(weightKg) },
            set: { weightKg = unit.toKg($0) }
        )
    }

    private var range: ClosedRange<Double> {
        unit == .kg ? 40...200 : 88...440
    }

    var body: some View {
        HStack {
            Slider(value: displayBinding, in: range, step: unit == .kg ? 0.5 : 1)
                .tint(MorphColors.accent)
            Text(unit.format(weightKg))
                .font(MorphFonts.mono(15))
                .foregroundColor(MorphColors.textPrimary)
                .frame(width: 80, alignment: .trailing)
        }
    }
}
