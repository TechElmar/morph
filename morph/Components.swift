import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Primary Button
struct MorphButton: View {
    let title: String
    var style: ButtonStyle = .primary
    var isDisabled: Bool = false
    let action: () -> Void

    enum ButtonStyle { case primary, secondary, ghost }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MorphFonts.heading(15))
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: MorphCorners.pill))
                .overlay(
                    RoundedRectangle(cornerRadius: MorphCorners.pill)
                        .stroke(strokeColor, lineWidth: style == .ghost ? 1 : 0)
                )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:   return isDisabled ? MorphColors.border : MorphColors.accent
        case .secondary: return MorphColors.surfaceHigh
        case .ghost:     return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:   return isDisabled ? MorphColors.textTertiary : MorphColors.background
        case .secondary: return MorphColors.textPrimary
        case .ghost:     return MorphColors.textSecondary
        }
    }

    private var strokeColor: Color {
        style == .ghost ? MorphColors.border : .clear
    }
}

// MARK: - Text Field
struct MorphTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: MorphSpacing.md) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(MorphColors.textTertiary)
                    .frame(width: 18)
            }
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(MorphFonts.body(15))
                    .foregroundColor(MorphColors.textPrimary)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .font(MorphFonts.body(15))
                    .foregroundColor(MorphColors.textPrimary)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
            }
        }
        .padding(.horizontal, MorphSpacing.md)
        .frame(height: 52)
        .background(MorphColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: MorphCorners.md))
        .overlay(RoundedRectangle(cornerRadius: MorphCorners.md).stroke(MorphColors.border, lineWidth: 1))
    }
}

// MARK: - Error Banner
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: MorphSpacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(MorphColors.destructive)
            Text(message)
                .font(MorphFonts.body(13))
                .foregroundColor(MorphColors.textSecondary)
        }
        .padding(MorphSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MorphColors.destructive.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: MorphCorners.md))
        .overlay(RoundedRectangle(cornerRadius: MorphCorners.md).stroke(MorphColors.destructive.opacity(0.3), lineWidth: 1))
    }
}
