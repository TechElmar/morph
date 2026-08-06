// Template for morph/Secrets.swift (which is intentionally not committed).
//
// To build this project:
//   1. Copy this file to morph/Secrets.swift
//   2. Deploy your own Supabase Edge Function proxy (see morph/SETUP.md)
//   3. Fill in your own values below
//
// The app will compile without AI functionality if the proxy is unreachable.

enum Secrets {
    /// Your base Supabase project URL.
    static let supabaseURL = "https://YOUR-PROJECT.supabase.co"

    /// Your Supabase Edge Function URL that proxies Anthropic API calls.
    static let aiProxyURL = "\(supabaseURL)/functions/v1/analyze-physique"

    /// Your Supabase publishable key.
    static let supabasePublishableKey = "sb_publishable_YOUR_KEY_HERE"
}
