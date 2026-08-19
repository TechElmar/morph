import SwiftUI

// MARK: - Landing Screen
struct LandingView: View {
    @State private var showSignIn = false
    @State private var showSignUp = false

    var body: some View {
        ZStack {
            MorphColors.background.ignoresSafeArea()

            // Background accent glow
            Circle()
                .fill(MorphColors.accent.opacity(0.06))
                .frame(width: 400, height: 400)
                .offset(x: 100, y: -200)
                .blur(radius: 80)

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: MorphSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: MorphCorners.xl)
                            .fill(MorphColors.accentDim)
                            .frame(width: 72, height: 72)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(MorphColors.accent)
                    }

                    Text("MORPH")
                        .font(MorphFonts.display(48))
                        .foregroundColor(MorphColors.textPrimary)
                        .tracking(8)

                    Text("AI Physique Coach")
                        .font(MorphFonts.body(16))
                        .foregroundColor(MorphColors.textSecondary)
                        .tracking(2)
                }

                Spacer()

                // Feature pills
                VStack(spacing: MorphSpacing.sm) {
                    FeaturePill(icon: "photo.stack", text: "4-Angle Weekly Photos")
                    FeaturePill(icon: "chart.bar.fill", text: "AI Scores on Symmetry, BF% & More")
                    FeaturePill(icon: "fork.knife", text: "Personalized Diet & Training Plans")
                }
                .padding(.horizontal, MorphSpacing.xl)

                Spacer()

                // CTAs
                VStack(spacing: MorphSpacing.md) {
                    MorphButton(title: "Get Started Free", style: .primary) {
                        showSignUp = true
                    }

                    Button("Already have an account? Sign In") {
                        showSignIn = true
                    }
                    .font(MorphFonts.body(15))
                    .foregroundColor(MorphColors.textSecondary)
                }
                .padding(.horizontal, MorphSpacing.xl)
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showSignUp) { SignUpView() }
        .sheet(isPresented: $showSignIn) { SignInView() }
    }
}

private struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: MorphSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(MorphColors.accent)
                .frame(width: 20)
            Text(text)
                .font(MorphFonts.body(14))
                .foregroundColor(MorphColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, MorphSpacing.md)
        .padding(.vertical, MorphSpacing.sm + 2)
        .morphCard()
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    enum Field { case name, email, password, confirm }

    var isValid: Bool {
        !name.isEmpty && AuthViewModel.isValidEmail(email) &&
        password.count >= 6 && password == confirmPassword
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: MorphSpacing.lg) {
                        // Header
                        VStack(spacing: MorphSpacing.sm) {
                            Text("Create Account")
                                .font(MorphFonts.heading(28))
                                .foregroundColor(MorphColors.textPrimary)
                            Text("Start your transformation")
                                .font(MorphFonts.body(15))
                                .foregroundColor(MorphColors.textSecondary)
                        }
                        .padding(.top, MorphSpacing.xl)

                        VStack(spacing: MorphSpacing.md) {
                            MorphTextField(placeholder: "Full Name", text: $name, icon: "person")
                                .focused($focusedField, equals: .name)

                            MorphTextField(placeholder: "Email", text: $email, icon: "envelope", keyboardType: .emailAddress)
                                .focused($focusedField, equals: .email)

                            if !email.isEmpty && !AuthViewModel.isValidEmail(email) {
                                Text("Please enter a valid email address")
                                    .font(MorphFonts.caption(11))
                                    .foregroundColor(MorphColors.destructive)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                            }

                            MorphTextField(placeholder: "Password (min 6 chars)", text: $password, icon: "lock", isSecure: !showPassword)
                                .focused($focusedField, equals: .password)

                            MorphTextField(placeholder: "Confirm Password", text: $confirmPassword, icon: "lock.fill", isSecure: !showPassword)
                                .focused($focusedField, equals: .confirm)

                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Text("Passwords don't match")
                                    .font(MorphFonts.caption(11))
                                    .foregroundColor(MorphColors.destructive)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                            }

                            // Show password toggle
                            Toggle(isOn: $showPassword) {
                                Text("Show password")
                                    .font(MorphFonts.caption())
                                    .foregroundColor(MorphColors.textSecondary)
                            }
                            .tint(MorphColors.accent)
                            .padding(.horizontal, 4)
                        }
                        .padding(.horizontal, MorphSpacing.xl)

                        if let error = authVM.errorMessage {
                            ErrorBanner(message: error)
                                .padding(.horizontal, MorphSpacing.xl)
                        }

                        MorphButton(
                            title: authVM.isLoading ? "Creating account…" : "Create Account",
                            style: .primary,
                            isDisabled: !isValid || authVM.isLoading
                        ) {
                            Task {
                                await authVM.signUp(email: email, password: password, name: name)
                                if authVM.isLoggedIn { dismiss() }
                            }
                        }
                        .padding(.horizontal, MorphSpacing.xl)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MorphColors.textSecondary)
                }
            }
        }
        .presentationBackground(MorphColors.background)
        .onAppear { authVM.errorMessage = nil }
    }
}

// MARK: - Sign In View
struct SignInView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()

                VStack(spacing: MorphSpacing.lg) {
                    VStack(spacing: MorphSpacing.sm) {
                        Text("Welcome Back")
                            .font(MorphFonts.heading(28))
                            .foregroundColor(MorphColors.textPrimary)
                        Text("Sign in to continue")
                            .font(MorphFonts.body(15))
                            .foregroundColor(MorphColors.textSecondary)
                    }
                    .padding(.top, MorphSpacing.xl)

                    VStack(spacing: MorphSpacing.md) {
                        MorphTextField(placeholder: "Email", text: $email, icon: "envelope", keyboardType: .emailAddress)
                        MorphTextField(placeholder: "Password", text: $password, icon: "lock", isSecure: true)
                    }
                    .padding(.horizontal, MorphSpacing.xl)

                    if let error = authVM.errorMessage {
                        ErrorBanner(message: error)
                            .padding(.horizontal, MorphSpacing.xl)
                    }

                    MorphButton(
                        title: authVM.isLoading ? "Signing in…" : "Sign In",
                        style: .primary,
                        isDisabled: email.isEmpty || password.isEmpty || authVM.isLoading
                    ) {
                        Task {
                            await authVM.signIn(email: email, password: password)
                            if authVM.isLoggedIn { dismiss() }
                        }
                    }
                    .padding(.horizontal, MorphSpacing.xl)

                    Button("Forgot password?") {
                        authVM.errorMessage = nil
                        showForgotPassword = true
                    }
                    .font(MorphFonts.body(14))
                    .foregroundColor(MorphColors.accent)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MorphColors.textSecondary)
                }
            }
        }
        .presentationBackground(MorphColors.background)
        .onAppear { authVM.errorMessage = nil }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(prefilledEmail: email)
        }
    }
}

// MARK: - Forgot Password
/// Two steps in one sheet: request a code, then set a new password with it.
/// Uses an emailed code rather than a magic link so the whole flow stays in
/// the app and needs no deep-link handling.
struct ForgotPasswordView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    let prefilledEmail: String

    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var codeSent = false

    private var canSend: Bool {
        AuthViewModel.isValidEmail(email) && !authVM.isLoading
    }
    private var canReset: Bool {
        code.count >= 6 && newPassword.count >= 6 &&
        newPassword == confirmPassword && !authVM.isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: MorphSpacing.lg) {
                        VStack(spacing: MorphSpacing.sm) {
                            Text(codeSent ? "Enter Your Code" : "Reset Password")
                                .font(MorphFonts.heading(28))
                                .foregroundColor(MorphColors.textPrimary)
                            Text(codeSent
                                 ? "We sent a 6-digit code to \(email). Enter it below along with your new password."
                                 : "Enter your email and we'll send you a code to reset your password.")
                                .font(MorphFonts.body(15))
                                .foregroundColor(MorphColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, MorphSpacing.xl)
                        .padding(.horizontal, MorphSpacing.xl)

                        VStack(spacing: MorphSpacing.md) {
                            MorphTextField(placeholder: "Email", text: $email,
                                           icon: "envelope", keyboardType: .emailAddress)
                                .disabled(codeSent)
                                .opacity(codeSent ? 0.6 : 1)

                            if codeSent {
                                MorphTextField(placeholder: "6-digit code", text: $code,
                                               icon: "number", keyboardType: .numberPad)
                                MorphTextField(placeholder: "New password (min 6 chars)",
                                               text: $newPassword, icon: "lock", isSecure: true)
                                MorphTextField(placeholder: "Confirm new password",
                                               text: $confirmPassword, icon: "lock.fill", isSecure: true)

                                if !confirmPassword.isEmpty && newPassword != confirmPassword {
                                    Text("Passwords don't match")
                                        .font(MorphFonts.caption(11))
                                        .foregroundColor(MorphColors.destructive)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 4)
                                }
                            }
                        }
                        .padding(.horizontal, MorphSpacing.xl)

                        if let error = authVM.errorMessage {
                            ErrorBanner(message: error)
                                .padding(.horizontal, MorphSpacing.xl)
                        }

                        if codeSent {
                            MorphButton(
                                title: authVM.isLoading ? "Resetting…" : "Reset Password",
                                style: .primary,
                                isDisabled: !canReset
                            ) {
                                Task {
                                    if await authVM.resetPassword(email: email, code: code,
                                                                  newPassword: newPassword) {
                                        dismiss()
                                    }
                                }
                            }
                            .padding(.horizontal, MorphSpacing.xl)

                            Button("Send a new code") {
                                code = ""
                                Task { _ = await authVM.requestPasswordReset(email: email) }
                            }
                            .font(MorphFonts.body(14))
                            .foregroundColor(MorphColors.accent)
                            .disabled(authVM.isLoading)
                        } else {
                            MorphButton(
                                title: authVM.isLoading ? "Sending…" : "Send Code",
                                style: .primary,
                                isDisabled: !canSend
                            ) {
                                Task {
                                    if await authVM.requestPasswordReset(email: email) {
                                        codeSent = true
                                    }
                                }
                            }
                            .padding(.horizontal, MorphSpacing.xl)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MorphColors.textSecondary)
                }
            }
        }
        .presentationBackground(MorphColors.background)
        .onAppear {
            authVM.errorMessage = nil
            if email.isEmpty { email = prefilledEmail }
        }
    }
}
