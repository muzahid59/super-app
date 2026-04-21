# Authentication & Login Flow Design

**Date:** 2026-04-21  
**App:** OCR Receipt Scanner (Flutter, Android)  
**Status:** Approved

---

## Overview

Add a Firebase-backed authentication system to the app with a fully decoupled abstraction layer so the backend can be swapped (e.g., to Supabase or AWS Cognito) with minimal code changes. All data lives in Firestore — no local persistence from prior app versions is in scope.

---

## Requirements

| Requirement | Detail |
|---|---|
| Registration fields | Full name (required, not unique), Phone (unique, required), Email (optional, profile only) |
| Login method | Phone number → Firebase SMS OTP |
| Single-device session | Silent logout on old device when user logs in on a new one |
| Platform | Android only |
| Backend | Firebase Auth + Firestore |
| Extensibility | All Firebase usage hidden behind abstract interfaces |

---

## Architecture

### Abstraction Layer

The app never imports Firebase packages directly outside of the implementation files. All other layers depend only on abstract Dart classes.

```
lib/
├── services/
│   └── auth/
│       ├── auth_service.dart                  ← abstract interface
│       └── firebase/
│           └── firebase_auth_service.dart     ← Firebase implementation
├── repositories/
│   ├── user_repository.dart                   ← abstract interface
│   ├── session_repository.dart                ← abstract interface
│   └── firebase/
│       ├── firestore_user_repository.dart     ← Firestore implementation
│       └── firestore_session_repository.dart  ← Firestore implementation
├── providers/
│   └── auth_provider.dart                     ← uses only abstract interfaces
└── screens/
    ├── login_screen.dart
    ├── register_screen.dart
    └── otp_screen.dart
```

### Dependency Injection

Wiring happens in a single place (`main.dart` or a `ServiceLocator`). To swap the backend, only these lines change:

```dart
final AuthService authService = FirebaseAuthService();
final UserRepository userRepo = FirestoreUserRepository();
final SessionRepository sessionRepo = FirestoreSessionRepository();
```

---

## Abstract Interfaces

### `AuthService`

```dart
abstract class AuthService {
  Future<void> sendOtp(String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  });

  Future<void> verifyOtp(String verificationId, String smsCode);

  Future<void> signOut();

  String? get currentUserId;
}
```

### `UserRepository`

```dart
abstract class UserRepository {
  Future<bool> phoneExists(String phone);
  Future<void> createUser(UserModel user);
  Future<UserModel?> getUserById(String uid);
}
```

### `SessionRepository`

```dart
abstract class SessionRepository {
  Future<void> writeSessionToken(String uid, String token);
  Future<String?> getSessionToken(String uid);
  Future<void> clearSession();
  Future<String?> getLocalSessionToken();
}
```

---

## Data Model

### Firestore `users/{uid}`

```json
{
  "uid": "firebase_auth_uid",
  "fullName": "John Doe",
  "phone": "+8801700000000",
  "email": "john@gmail.com",      // nullable
  "sessionToken": "uuid-v4",
  "createdAt": "timestamp"
}
```

Phone uniqueness is enforced by Firebase Auth itself — no separate Firestore collection needed.

---

## Authentication Flows

### App Startup

1. Check if Firebase has a local session (Firebase Auth `currentUser`)
2. If no session → navigate to Login Screen
3. If session exists → fetch `sessionToken` from Firestore
4. Compare against locally stored `sessionToken` (SharedPreferences)
5. Match → navigate to Home Screen
6. Mismatch → clear local session → navigate to Login Screen (silent)

### Login Flow

1. User enters phone number
2. `AuthService.sendOtp()` → Firebase sends SMS
3. User enters 6-digit code on OTP Screen
4. `AuthService.verifyOtp()` → Firebase verifies
5. `UserRepository.phoneExists()` → check Firestore
   - **Phone found:** load user profile, generate new `sessionToken`, write to Firestore + local storage → Home
   - **Phone not found:** navigate to Register Screen (phone pre-filled)

### Registration Flow

1. Arrives from Login with phone number pre-filled and OTP already verified
2. User enters full name (required) + email (optional)
3. On submit: create `users/{uid}` in Firestore (no uniqueness check needed — phone already verified as unique by Firebase Auth)
4. Generate `sessionToken`, write to Firestore + local storage → Home

### Single-Device Session

- `sessionToken` is a UUID generated at each successful login/register
- Stored in: Firestore `users/{uid}.sessionToken` + device `SharedPreferences`
- On each app start: compare the two → mismatch means another device logged in → force logout

---

## Firestore Security Rules (outline)

```
users/{uid}:
  - read: uid == request.auth.uid
  - write: uid == request.auth.uid
```

---

## Screens

| Screen | Purpose |
|---|---|
| `LoginScreen` | Phone number input + "Send OTP" button |
| `OtpScreen` | 6-digit OTP entry, resend timer |
| `RegisterScreen` | Full name + optional email, submit creates account |

Navigation is handled via `AuthProvider` state — screens observe auth state, not each other.

---

## Dependencies to Add

```yaml
# pubspec.yaml additions
firebase_core: ^3.x
firebase_auth: ^5.x
cloud_firestore: ^5.x
shared_preferences: ^2.x
uuid: ^4.x  # already present
```

---

## What Is Explicitly Out of Scope

- Email-based login (stored as profile field only, not a login method)
- iOS support
- Password-based authentication
- Social login (Google, Facebook, etc.)
- Account deletion / phone number change flows
- Push notifications for session events

---

## Swap Cost Estimate (replacing Firebase later)

To replace Firebase with another backend:
1. Write new implementations of `AuthService`, `UserRepository`, `SessionRepository`
2. Update the 3 lines in `main.dart` / `ServiceLocator`
3. Remove Firebase packages from `pubspec.yaml`

No screens, providers, or business logic needs to change.
