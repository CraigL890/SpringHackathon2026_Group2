## [2026-03-08] - Remove QR code generation tab

- Removed the QR code tab from `HomeScreen` (`_buildGenerateTab`, bottom nav item, import)
- Removed `qr_flutter` dependency from `pubspec.yaml`
- Map tab is now the default (index 0)
- Files affected: `lib/screens/home_screen.dart`, `pubspec.yaml`

## [2026-03-08] - Fix Google Maps TypeError on web

- **Root cause**: `google_maps_flutter` on web requires the Google Maps JavaScript API to be loaded via a `<script>` tag in `web/index.html`. It was missing, causing `TypeError: Cannot read properties of undefined (reading 'maps')` (`google.maps` was undefined).
- **Fix**: Added the Maps JS API script tag with the existing API key to `web/index.html`.
- Files affected: `web/index.html`

## [2026-03-08] - Fix navigation not reaching HomeScreen after verification

- **Root cause**: `LandingScreen` uses `Navigator.push` to open `LoginScreen`, putting it on top of the navigation stack. After sign-in, `main.dart`'s `StreamBuilder` rebuilt its `home` widget to `HomeScreen`, but `LoginScreen` remained on top of the stack — so the user never saw `HomeScreen`. The location permission dialog appeared because `HomeScreen` was instantiated at the bottom of the stack (its `initState` ran), but was hidden behind `LoginScreen`.
- **Fix**: After successful `signInWithCredential`, call `Navigator.popUntil((route) => route.isFirst)` to clear back to the root route, which `StreamBuilder` has already updated to `HomeScreen`.
- Files affected: `lib/screens/login_screen.dart`

## [2026-03-08] - Fix infinite loading after verification code submission

- **Root cause 1**: After a successful `signInWithCredential` in `_verifyCode()`, `_loading` was never reset to `false`, leaving the spinner stuck. Also missing `mounted` guard on async callbacks.
- **Root cause 2**: The `FutureBuilder` in `main.dart` that checks the `businesses` Firestore collection had no timeout or error handling. If Firestore was slow or blocked by security rules, it would hang on the loading spinner indefinitely.
- **Fix**: Added a 10-second timeout to the Firestore `.get()` call, added explicit `!bizSnap.hasError` check before routing to `BusinessDashboardScreen`, and reset `_loading = false` on success in `_verifyCode()`.
- Files affected: `lib/main.dart`, `lib/screens/login_screen.dart`
