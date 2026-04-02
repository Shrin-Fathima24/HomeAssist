# Fix Authentication Issues (Login/Signup)

## Analysis
- Signup: FirebaseAuth succeeds (blocks duplicates), Firestore write fails → no success msg, shows generic error
- Login: Firestore read fails (doc missing + rules) → "unexpected error", no navigation

## Steps:
- [ ] Step 1: Set Firestore Rules in Firebase Console (see below)
- [x] Step 2: Add debug logging to login.dart & signup_page.dart ✓
- [ ] Step 3: `flutter pub get && flutter run` → check console prints for exact errors
- [ ] Step 4: Verify Firebase Console: Authentication → Users created; Firestore → users collection docs?
- [ ] Step 5: Test login → should navigate to role-based home
- [ ] Step 6: Mark complete & run attempt_completion

## Firestore Security Rules
Go to https://console.firebase.google.com/project/home-317c3/firestore/rules → Replace with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```
→ **Publish** rules. This allows signed-in users to read/write their own user doc.

## Testing Commands
```
cd securehome
flutter clean
flutter pub get
flutter run
```
Look for `print` statements in VSCode debug console or terminal.

**Expected**: After rules + logging, signup creates doc + shows success; login reads doc + navigates.

