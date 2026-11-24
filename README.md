# DockPeek

Windows-artige Fenstervorschau für das macOS-Dock: Fährst du mit der Maus über ein
Programm im Dock, zeigt DockPeek Vorschaubilder aller Fenster dieses Programms.

| Aktion | Wirkung |
|---|---|
| Über Dock-Icon hovern | Vorschau aller Fenster (inkl. minimierter) |
| Klick auf Vorschau | Genau dieses Fenster nach vorne holen (auch aus dem Dock/minimiert) |
| `×` auf der Vorschau | Fenster schließen |
| Mittelklick auf Vorschau | Fenster schließen |
| Klick irgendwo anders / Maus weg | Vorschau ausblenden |

Funktioniert mit dem Dock unten, links und rechts sowie auf mehreren Bildschirmen.
DockPeek läuft als Menüleisten-App (kein eigenes Dock-Icon).

## Voraussetzungen

- macOS 14 (Sonoma) oder neuer
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Loslegen

```bash
cp Config.example.xcconfig Config.xcconfig   # DEVELOPMENT_TEAM eintragen
xcodegen generate
open DockPeek.xcodeproj
```

Dann in Xcode **Run** (⌘R).

> **Wichtig: Signierung.** macOS bindet die Bedienungshilfen-Berechtigung an die
> Code-Signatur. Ohne `DEVELOPMENT_TEAM` (ad-hoc signiert) musst du die Berechtigung
> nach jedem Build neu erteilen. Ein kostenloser Apple-Account als Team reicht.

## Berechtigungen

Beim ersten Start fragt DockPeek nach:

1. **Bedienungshilfen** (erforderlich) – um das Dock zu beobachten und Fenster anderer
   Apps aufzulisten, nach vorne zu holen und zu schließen.
2. **Bildschirmaufnahme** (optional) – für die Vorschaubilder. Ohne diese Berechtigung
   zeigt DockPeek Fenstertitel mit App-Icon.

Beides findest du unter *Systemeinstellungen → Datenschutz & Sicherheit*, oder über das
Menüleisten-Icon von DockPeek.

## Wie es funktioniert

```
Dock (AX)  ──AXSelectedChildrenChanged──▶  DockObserver
                                               │ DockItem (App + Icon-Frame)
                                               ▼
                                       PreviewCoordinator ──▶ WindowProvider (AX-Fensterliste)
                                               │          ──▶ ThumbnailService (ScreenCaptureKit)
                                               ▼
                                   PreviewPanel (NSPanel + SwiftUI)
                                               │ Klick / ×
                                               ▼
                                         WindowActions (AXRaise / AXPress)
```

- **Hover-Erkennung:** Das Dock meldet über die Accessibility-API, welches Icon gerade
  „ausgewählt“ ist, während die Maus darüber fährt. Es wird also nichts gepollt, solange
  keine Vorschau offen ist.
- **Fensterliste:** `kAXWindowsAttribute` der App. Die Zuordnung zur `CGWindowID` passiert
  über die private, aber seit Jahren stabile Funktion `_AXUIElementGetWindow` (wie bei
  AltTab, Rectangle, DockDoor).
- **Vorschaubilder:** `SCScreenshotManager` (macOS 14+). Minimierte Fenster zeigen ihr
  letztes bekanntes Bild aus dem Cache.
- **Kein App Store:** Dock-Beobachtung und Fenstersteuerung funktionieren nicht in der
  App-Sandbox. Verteilung als signierte, notarisierte App außerhalb des App Stores.

## Bekannte Einschränkungen (MVP)

- Nur Fenster auf dem **aktuellen Space** (plus minimierte). Fenster auf anderen Spaces oder
  in Vollbild-Spaces werden noch nicht angezeigt.
- Bei sehr vielen Fenstern werden nur so viele gezeigt, wie auf den Bildschirm passen
  (noch kein Scrollen).
- Minimierte Fenster haben erst dann ein Vorschaubild, wenn DockPeek sie einmal sichtbar
  gesehen hat.

## Roadmap

- [ ] Fenster anderer Spaces/Vollbild
- [ ] Einstellungen (Verzögerung, Vorschaugröße)
- [ ] Klick auf aktives Dock-Icon minimiert (Windows-Verhalten)
- [ ] Alt+Tab pro Fenster
- [ ] Snap / Fenster an den Rand ziehen
