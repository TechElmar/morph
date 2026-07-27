import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionVM: SubscriptionViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedProductID = SubscriptionViewModel.yearlyProductID

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()

                // Accent glow
                Circle()
                    .fill(MorphColors.accent.opacity(0.08))
                    .frame(width: 400, height: 400)
                    .offset(y: -320)
                    .blur(radius: 60)

                ScrollView {
                    VStack(spacing: MorphSpacing.lg) {

                        // Hero
                        VStack(spacing: MorphSpacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: MorphCorners.xl)
                                    .fill(MorphColors.accentDim)
                                    .frame(width: 64, height: 64)
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(MorphColors.accent)
                            }

                            Text("MORPH PRO")
                                .font(MorphFonts.display(30))
                                .foregroundColor(MorphColors.textPrimary)
                                .tracking(4)

                            Text("Check in every single day.\nTrack your transformation in real time.")
                                .font(MorphFonts.body(15))
                                .foregroundColor(MorphColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .padding(.top, MorphSpacing.lg)

                        // Free vs Pro comparison
                        VStack(spacing: 0) {
                            ComparisonHeader()
                            ComparisonRow(feature: "AI check-ins", free: "1 / week", pro: "1 / day")
                            ComparisonRow(feature: "Scores & macros", free: "✓", pro: "✓")
                            ComparisonRow(feature: "Photo comparison", free: "✓", pro: "✓")
                            ComparisonRow(feature: "Day-by-day trends", free: "—", pro: "✓")
                            ComparisonRow(feature: "Cut & bulk tracking", free: "—", pro: "✓", isLast: true)
                        }
                        .morphCard()
                        .padding(.horizontal, MorphSpacing.xl)

                        // Product options
                        if subscriptionVM.products.isEmpty {
                            VStack(spacing: MorphSpacing.md) {
                                Text("Subscription options are loading…")
                                    .font(MorphFonts.body(13))
                                    .foregroundColor(MorphColors.textSecondary)
                                Button("Retry") {
                                    Task { await subscriptionVM.loadProducts() }
                                }
                                .font(MorphFonts.caption(13))
                                .foregroundColor(MorphColors.accent)
                            }
                            .padding(MorphSpacing.lg)
                        } else {
                            VStack(spacing: MorphSpacing.sm) {
                                ForEach(subscriptionVM.products, id: \.id) { product in
                                    ProductOptionCard(
                                        product: product,
                                        isSelected: selectedProductID == product.id,
                                        badge: product.id == SubscriptionViewModel.yearlyProductID
                                            ? subscriptionVM.yearlySavings : nil
                                    ) {
                                        selectedProductID = product.id
                                        Haptics.tap()
                                    }
                                }
                            }
                            .padding(.horizontal, MorphSpacing.xl)
                        }

                        if let error = subscriptionVM.errorMessage {
                            ErrorBanner(message: error)
                                .padding(.horizontal, MorphSpacing.xl)
                        }

                        // CTA
                        MorphButton(
                            title: subscriptionVM.isLoading ? "Processing…" : "Start PRO",
                            style: .primary,
                            isDisabled: subscriptionVM.isLoading || subscriptionVM.products.isEmpty
                        ) {
                            if let product = subscriptionVM.products.first(where: { $0.id == selectedProductID }) {
                                Task { await subscriptionVM.purchase(product) }
                            }
                        }
                        .padding(.horizontal, MorphSpacing.xl)

                        Button("Restore Purchases") {
                            Task { await subscriptionVM.restorePurchases() }
                        }
                        .font(MorphFonts.caption(13))
                        .foregroundColor(MorphColors.textSecondary)

                        // Legal
                        VStack(spacing: MorphSpacing.sm) {
                            Text("Subscription auto-renews unless cancelled at least 24 hours before the end of the period. Payment is charged to your Apple ID. Manage or cancel anytime in App Store settings.")
                                .font(MorphFonts.caption(10))
                                .foregroundColor(MorphColors.textTertiary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: MorphSpacing.lg) {
                                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                Link("Privacy Policy", destination: URL(string: "https://techelmar.github.io/morph/privacy.html")!)
                            }
                            .font(MorphFonts.caption(11))
                            .foregroundColor(MorphColors.textTertiary)
                        }
                        .padding(.horizontal, MorphSpacing.xl)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(MorphColors.textSecondary)
                    }
                }
            }
        }
        .presentationBackground(MorphColors.background)
        .onChange(of: subscriptionVM.purchaseJustSucceeded) { _, succeeded in
            if succeeded {
                subscriptionVM.purchaseJustSucceeded = false
                dismiss()
            }
        }
    }
}

// MARK: - Comparison Table
private struct ComparisonHeader: View {
    var body: some View {
        HStack {
            Text("")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("FREE")
                .font(MorphFonts.caption(10))
                .foregroundColor(MorphColors.textTertiary)
                .tracking(1)
                .frame(width: 70)
            Text("PRO")
                .font(MorphFonts.caption(10))
                .foregroundColor(MorphColors.accent)
                .tracking(1)
                .frame(width: 70)
        }
        .padding(.horizontal, MorphSpacing.md)
        .padding(.top, MorphSpacing.md)
        .padding(.bottom, MorphSpacing.sm)
    }
}

private struct ComparisonRow: View {
    let feature: String
    let free: String
    let pro: String
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(feature)
                    .font(MorphFonts.body(13))
                    .foregroundColor(MorphColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(free)
                    .font(MorphFonts.caption(12))
                    .foregroundColor(free == "—" ? MorphColors.textTertiary : MorphColors.textSecondary)
                    .frame(width: 70)
                Text(pro)
                    .font(MorphFonts.caption(12))
                    .foregroundColor(MorphColors.accent)
                    .frame(width: 70)
            }
            .padding(.horizontal, MorphSpacing.md)
            .padding(.vertical, MorphSpacing.sm + 2)

            if !isLast {
                Divider().background(MorphColors.border)
                    .padding(.horizontal, MorphSpacing.md)
            }
        }
    }
}

// MARK: - Product Option
private struct ProductOptionCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let onTap: () -> Void

    private var periodLabel: String {
        guard let sub = product.subscription else { return "" }
        switch sub.subscriptionPeriod.unit {
        case .year:  return "per year"
        case .month: return "per month"
        case .week:  return "per week"
        case .day:   return "per day"
        @unknown default: return ""
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MorphSpacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? MorphColors.accent : MorphColors.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: MorphSpacing.sm) {
                        Text(product.displayName)
                            .font(MorphFonts.heading(15))
                            .foregroundColor(MorphColors.textPrimary)
                        if let badge = badge {
                            Text(badge)
                                .font(MorphFonts.caption(10))
                                .foregroundColor(MorphColors.background)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(MorphColors.accent)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(product.displayPrice) \(periodLabel)")
                        .font(MorphFonts.caption(12))
                        .foregroundColor(MorphColors.textSecondary)
                }
                Spacer()
            }
            .padding(MorphSpacing.md)
            .background(isSelected ? MorphColors.accentDim : MorphColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: MorphCorners.md))
            .overlay(
                RoundedRectangle(cornerRadius: MorphCorners.md)
                    .stroke(isSelected ? MorphColors.accent : MorphColors.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
