# DockDIY

DockDIY is a small macOS utility for creating custom Dock launcher groups.

Create a group, choose the apps inside it, pick a simple icon, then add the
generated launcher to the left side of the Dock. Clicking the launcher opens a
Dock-style popup panel with grid or list display.

## Features

- Create app groups managed by DockDIY
- Choose a built-in icon for each group
- Add group launchers to the left side of the Dock
- Popup panel with grid and list display modes
- Search apps inside the popup
- Edit group apps and remove apps quickly

## Requirements

- macOS 14 or later
- Xcode 16 or later for local development
- XcodeGen for regenerating the Xcode project

## Build

```sh
xcodegen generate
xcodebuild build -project DockDIY.xcodeproj -scheme DockDIY -configuration Release -destination 'platform=macOS'
```

The release app will be produced under Xcode DerivedData.

## License

MIT
