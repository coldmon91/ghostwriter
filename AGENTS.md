# Repository Guidelines

## Project Structure & Module Organization

Ghostwriter is a macOS Swift application generated from `project.yml` with XcodeGen. Code lives under
`Ghostwriter/` and is organized by role:

- `Ghostwriter/AIMemoApp.swift`: app entry point.
- `Ghostwriter/Models/`: persisted domain types such as documents, snippets, and history.
- `Ghostwriter/Services/`: storage, AI streaming clients, settings, and hotkey integration.
- `Ghostwriter/ViewModels/`: presentation state for editor, settings, and tabs.
- `Ghostwriter/Views/`: SwiftUI and AppKit-backed UI components.
- `Ghostwriter/Extensions/`: focused framework extensions.
- `Ghostwriter/Resources/`: app resources and assets.

Keep new files in the matching role directory. Put shared behavior in reusable services or helpers.

## Build, Test, and Development Commands

- `./run.sh`: generate the Xcode project if needed, build Debug, then launch the app.
- `./run.sh --build-only`: build Debug without launching.
- `./run.sh --release --build-only`: build the Release configuration.
- `./run.sh --clean --build-only`: clean, regenerate if needed, and build.
- `xcodegen generate`: regenerate `Ghostwriter.xcodeproj` after project structure changes.

`run.sh` requires Xcode, `xcodebuild`, and XcodeGen. Install XcodeGen with `brew install xcodegen` when missing.

## Coding Style & Naming Conventions

Use Swift 5.9 conventions and Xcode's default Swift formatter. Prefer four-space indentation, descriptive names, and
clear separation between `View`, `ViewModel`, `Model`, and `Service` responsibilities. Name SwiftUI views with a
`View` suffix, view models with `ViewModel`, and stores or clients by role, for example `SettingsStore`.

Handle fallible operations explicitly and avoid force unwraps in production code. Keep UI state in view models, and
persistence or network concerns in services.

## Testing Guidelines

No test target is currently defined in `project.yml`. When adding tests, create `GhostwriterTests`, place tests in a
matching test directory, and use XCTest. Name test files after the unit under test, for example
`SettingsStoreTests.swift`, and use method names that describe behavior, such as
`testLoadsDefaultSettingsWhenFileIsMissing()`.

Run the app build before submitting changes:

- `./run.sh --build-only`

## Commit & Pull Request Guidelines

This directory does not currently expose repo-local Git history, so no commit convention could be verified here.
Use concise imperative commit messages such as `Add snippet persistence` or `Fix settings save failure`.

Pull requests should include a short summary, user-visible impact, test or build results, and screenshots for UI
changes. Link related issues when available and call out changes to `project.yml` or `Ghostwriter.xcodeproj`.

## Security & Configuration Tips

Do not commit API keys, local settings, or derived build products. Keep bundle ID, entitlements, signing settings, and
dependencies in `project.yml` so the generated Xcode project stays reproducible.
