# LevelUp — Flutter + Firebase Starter

### Quickstart
1) Create Flutter app and add Firebase:
```bash
flutter create levelup_flutter
cd levelup_flutter
# Replace files with this ZIP contents
dart pub add firebase_core firebase_auth cloud_firestore google_sign_in flutter_riverpod intl google_fonts
flutterfire configure   # generates lib/firebase_options.dart
flutter pub get
flutter run
```

2) (Optional) Cloud Functions
```bash
cd functions
npm i
npm run build
firebase deploy --only functions
```

### Firestore rules
Deploy `firestore.rules` via Firebase Console or CLI.

### Data model
- `users/{uid}`: { displayName, totalXP, categoryXP: {Body: int, Mind: int, ...} }
- `users/{uid}/habits/{hid}`: { title, category, description, emoji, xp, streak, history[], xpSmall, xpMedium, xpLarge, favorite, todayLevel }
- `leaderboards/global`: { entries: { uid: { totalXP } } } (demo)

### Notes
- `lib/firebase_options.dart` is a stub; run `flutterfire configure`.
- S/M/L button logic is differential and updates streak + history on first check of the day.
