# App Icon Design

## Goal

Use the supplied sleeping-cat image as Sleepy's iOS app icon.

## Design

- Preserve the image exactly as supplied, including its black background and white pixel art.
- Upscale the square source image to 1024×1024 with nearest-neighbor sampling so edges remain crisp.
- Store the result in a standard `Assets.xcassets/AppIcon.appiconset` asset catalog.
- Configure the Sleepy target to use the `AppIcon` set in Debug and Release builds.

## Verification

- Confirm the generated icon is square, 1024×1024, PNG, and opaque.
- Build the Sleepy target and confirm the asset catalog compiles without app-icon warnings.

## Scope

No redesign, background removal, alternate appearances, or unrelated project changes are included.
