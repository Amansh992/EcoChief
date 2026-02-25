# Swift Student Challenge submission checklist

This project has been prepared to align with the Swift Student Challenge policy baseline.

## Included compliance changes

- English-only app behavior is enforced in runtime copy paths.
- Offline-first AI is the default behavior.
- A Swift package app configuration (`Package.swift`) is included for app-playground style packaging.
- Project size is well below the 25 MB zipped limit.

## Before submitting

1. Open the package in Xcode using `Package.swift`.
2. Confirm the app runs fully offline in Simulator.
3. Confirm app flow can be experienced inside 3 minutes.
4. If needed by upload flow, rename the package folder to `EcoChef.swiftpm`.
5. Zip the package folder for upload.

## Optional local AI testing (not required for submission)

If you want to test remote AI providers locally, set:

- `ALLOW_REMOTE_AI=1`
- plus provider keys (`OPENAI_API_KEY` or `GEMINI_API_KEY`)

For challenge submission, leaving `ALLOW_REMOTE_AI` unset keeps the app offline-first.
