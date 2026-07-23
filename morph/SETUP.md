# Morph — iOS App Setup Guide
## Complete Xcode Project from Scratch

---

## 1. Create the Xcode Project

1. Open **Xcode** → **Create New Project**
2. Choose **iOS → App**
3. Fill in:
   - **Product Name:** `Morph`
   - **Bundle Identifier:** `com.yourname.morph` (must match App Store Connect later)
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Minimum Deployments:** iOS 17.0
4. Click **Next**, save to your preferred folder

---

## 2. Add the Source Files

Delete the default `ContentView.swift` that Xcode creates.

Then add **all the `.swift` files** from this project into your Xcode project:

```
MorphApp.swift
DesignSystem.swift
Models/Models.swift
ViewModels/AuthViewModel.swift
ViewModels/SubscriptionViewModel.swift
ViewModels/CheckInViewModel.swift
Services/ClaudeAIService.swift
Views/RootView.swift
Views/AuthViews.swift
Views/OnboardingView.swift
Views/DashboardView.swift
Views/CheckInView.swift
Views/HistoryView.swift
Views/PaywallView.swift
Views/ProfileView.swift
Components/Components.swift
```

**How to add:** In Xcode, right-click the `Morph` group in the Project Navigator → **Add Files to "Morph"**, select all the `.swift` files.

---

## 3. Configure Info.plist

In your project's `Info.plist`, add these keys (or replace its contents with the provided `Info.plist`):

| Key | Value |
|-----|-------|
| `NSPhotoLibraryUsageDescription` | `Morph needs access to your photo library to select your physique photos for AI analysis.` |
| `NSCameraUsageDescription` | `Morph needs your camera to take physique check-in photos.` |
| `ANTHROPIC_API_KEY` | `$(ANTHROPIC_API_KEY)` |

---

## 4. Set Your Anthropic API Key

**For development testing:**

1. In Xcode, click your scheme name (top bar, next to device) → **Edit Scheme**
2. Select **Run** → **Arguments** → **Environment Variables**
3. Add: `ANTHROPIC_API_KEY` = `sk-ant-your-key-here`

**⚠️ For production (App Store):**
Never ship your API key in the app. Instead:
- Set up a **backend proxy** (Supabase Edge Function, Firebase Function, your own server)
- The proxy receives requests from your app, adds the API key server-side, forwards to Anthropic
- Your app calls `https://yourbackend.com/analyze` instead of Anthropic directly
- This keeps your key off user devices

---

## 5. Add Capabilities in Xcode

Go to **Project → Target → Signing & Capabilities** and add:
- ✅ **Push Notifications** (optional, for weekly check-in reminders)

---

## 7. Swap Photo Access to Camera (Optional Enhancement)

The current `PhotoSlot` uses `PhotosPicker` (library). To also support live camera:

```swift
// Add to CheckInView imports:
import AVFoundation

// Add a camera capture button alongside the PhotosPicker
// Use UIImagePickerController wrapped in a UIViewControllerRepresentable
```

A full camera implementation is straightforward — just create a `CameraView: UIViewControllerRepresentable` wrapping `UIImagePickerController` with `.sourceType = .camera`.

---

## 8. Backend Proxy (Production — Recommended)

Here's a minimal **Supabase Edge Function** to proxy Anthropic API calls securely:

```typescript
// supabase/functions/analyze-physique/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const body = await req.json()
  
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(body),
  })
  
  const data = await response.json()
  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  })
})
```

Then in `ClaudeAIService.swift`, change:
```swift
private let endpoint = "https://yourproject.supabase.co/functions/v1/analyze-physique"
```
And add your Supabase anon key as a header instead of the Anthropic key.

---

## 9. Build & Test

1. Select an **iPhone 15** simulator or your physical device
2. **Cmd+R** to build and run
3. Sign up → complete onboarding → add 4 test photos → submit check-in
4. The AI analysis will call Claude and return scores

---

## File Structure Summary

```
morph/
├── morphApp.swift              # App entry point (@main)
├── DesignSystem.swift          # Colors, fonts, spacing, view modifiers
├── Info.plist                  # Camera + photo library permissions
├── Models.swift                # UserProfile, PhysiqueCheckIn, PhysiqueAnalysis
├── AuthViewModel.swift         # Login/signup/session state (UserDefaults)
├── CheckInViewModel.swift      # Photo submission, analysis state, tab routing
├── ClaudeAIService.swift       # Anthropic API integration (vision + coaching)
├── RootView.swift              # Navigation root (auth → onboarding → main)
├── AuthViews.swift             # Landing, SignUp, SignIn screens
├── OnboardingView.swift        # 4-step onboarding flow
├── DashboardView.swift         # Home tab + score cards + recommendations
├── CheckInView.swift           # Photo upload, submission, success overlay
├── HistoryView.swift           # Progress history, trend chart, detail view
├── ProfileView.swift           # Settings + profile editing
└── Components.swift            # MorphButton, MorphTextField, ErrorBanner
```
