## [2026-03-08] - Fix infinite loading after verification code submission

- **Root cause 1**: After a successful `signInWithCredential` in `_verifyCode()`, `_loading` was never reset to `false`, leaving the spinner stuck. Also missing `mounted` guard on async callbacks.
- **Root cause 2**: The `FutureBuilder` in `main.dart` that checks the `businesses` Firestore collection had no timeout or error handling. If Firestore was slow or blocked by security rules, it would hang on the loading spinner indefinitely.
- **Fix**: Added a 10-second timeout to the Firestore `.get()` call, added explicit `!bizSnap.hasError` check before routing to `BusinessDashboardScreen`, and reset `_loading = false` on success in `_verifyCode()`.
- Files affected: `lib/main.dart`, `lib/screens/login_screen.dart`
