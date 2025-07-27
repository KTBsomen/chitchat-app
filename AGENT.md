# ChitChat Flutter App - Agent Guidelines

## Build/Lint/Test Commands
- Build: `flutter build apk` (Android) or `flutter build ios` (iOS)
- Lint: `flutter analyze` 
- Format: `dart format lib/`
- Dependencies: `flutter pub get`
- Clean: `flutter clean`
- Run: `flutter run`
- No tests directory exists - tests need to be created in `test/` folder
- Single test: `flutter test test/specific_test.dart`

## Architecture & Structure
- Flutter app with Firebase integration (project: questionapp-a3d85)
- Custom local packages: `chatview` and `deep_link_router` (path dependencies)
- Main services: user auth (Google Sign-In), FCM notifications, MQTT messaging, file upload
- Key directories: `lib/services/` (business logic), `lib/screens/` (UI), `lib/components/` (widgets)
- External API base: https://chitzchat.com/api/v1
- Uses Firebase for auth, FCM, and backend services

## Code Style & Conventions
- Follows flutter_lints standards
- Class names: PascalCase (e.g., `LoginScreen`, `AppColors`)
- File names: camelCase (e.g., `createStory.dart`, `fileUploader.dart`)
- Import order: dart core, packages, relative imports
- Colors defined in `lib/constants/colors.dart` as static constants
- Font families: PassionOne (headings), Poppins (body text)
- State management: setState pattern, services for shared state
- Navigation: MaterialPageRoute with PageTransition for iOS-style transitions
