# SWS merged update: requested features + local SQLite cache

This package is based on the feature-updated project, with the SQLite/IndexedDB local cache backend integrated without replacing the traveler workflow, avatar, ticket-booking, skeleton, search, or dashboard source files with the older snapshot.

## Storage behavior
- Windows/Android: SQLite cache via sqflite; FFI driver for desktop.
- Web: SQLite/WASM through sqflite_common_ffi_web, persisted in browser IndexedDB. Run `dart run sqflite_common_ffi_web:setup` before building web to generate the required web runtime files.
- Supabase remains the source of truth. This cache stores UI snapshots only; it does not queue financial mutations offline.
- Existing SharedPreferences cache snapshots are not migrated; they can be fetched from Supabase again. No Supabase production data or schema was changed by packaging this project.

## Verify before release
Run `flutter pub get`, `dart run sqflite_common_ffi_web:setup`, `flutter analyze`, `flutter test`, then build each target. This environment does not have Flutter installed, so no successful build is claimed.
