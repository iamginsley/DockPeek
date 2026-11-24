# DockPeek

Menu bar app for macOS that brings the Windows taskbar's window previews to the Dock: hover over an app icon and DockPeek shows all of that app's windows as thumbnails. Click one to bring it forward (minimized windows are restored), × or a middle-click closes it. Clicking the Dock icon of the app already in front minimizes its front window, like the Windows taskbar.

## How it works

- `DockObserver` watches the Dock through Accessibility. The Dock marks the icon under the pointer as the selected child of its icon list and posts `kAXSelectedChildrenChangedNotification`, so there is no mouse polling while idle.
- `WindowService` lists the app's standard windows (`kAXWindowsAttribute`, current Space, minimized included) and maps them to window server IDs with `_AXUIElementGetWindow`.
- `ThumbnailService` captures thumbnails with ScreenCaptureKit and keeps the last image per window, so minimized windows still show their content once seen.
- `PreviewPanel` is a non-activating, borderless panel above the Dock level; the app in front keeps focus. While it is visible a 30 Hz timer hides it once the pointer has left the icon and the panel for 250 ms; any click elsewhere dismisses it.
- `ClickToMinimize` watches clicks on the Dock and judges them by the state at press time (app was already in front, window was open), since global mouse events arrive late.
- `ThumbnailService` also captures the front app's windows every 3 s (setting „Inhalt minimierter Fenster zeigen“), so windows minimized later keep a recent thumbnail.
- `PeekOverlay` (Aero Peek): after resting 0.4 s on a thumbnail, a frosted overlay right below the Dock level covers every screen and shows a full-size snapshot of that window at its real frame. Minimized windows have no place on screen, so they get no peek. macOS has no public API to fade other apps' windows, hence the snapshot.
- `Preferences` holds every setting (UserDefaults); the settings window (⌘,) has a switch per feature, plus thumbnail size and hover delay.
- `PreviewLayout` (pure, unit-tested) finds the Dock edge and places the panel above or beside the icon, kept on screen.

Permissions: **Accessibility** (required; picked up without a restart) and **Screen Recording** (thumbnails; without it the preview shows titles and app icons). Both make the App Sandbox and the Mac App Store impossible, so DockPeek ships signed with Developer ID and notarized.

Known limits of v0.1: windows on other Spaces are not listed (Accessibility only returns the current Space).

## Design

Clean like Apple's own utilities. The preview uses Liquid Glass (`glassEffect`) since it floats; cards highlight on hover, the close button turns red on hover like in Windows. Colors are system colors; accent is system blue.

## Project structure

```
DockPeek/
  App/                 app entry, MenuBarExtra
  Core/Models/         AppWindow, DockItem, Preferences, PreviewLayout (pure logic)
  Core/Services/       Accessibility helpers, Dock observer, windows, thumbnails, permissions, login item
  Core/Demo/           sample windows for -DockPeekDemo (Debug only)
  Features/Preview/    preview panel, view, view model, Aero Peek overlay
  Features/Settings/   menu bar panel, settings window, shared view model
  Resources/           assets, Info.plist, privacy manifest
DockPeekTests/         layout tests
docs/                  privacy policy
```

## Build

```sh
xcodegen generate
open DockPeek.xcodeproj
```

Tests: `xcodebuild -project DockPeek.xcodeproj -scheme DockPeek test`

Debug launch flags: `-DockPeekDemo` shows sample previews above the bottom center of the main screen; `-DockPeekSettings <general|preview|clicks>` opens the settings on that page; `-DockPeekDump <bundle id>` logs the windows DockPeek sees for that app.
