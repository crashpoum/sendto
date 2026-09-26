# SendTo

Send files, folders, or clipboard to another machine on the network. No account. No cloud.

Works on **Windows** and **Android**. Linux coming soon.

## Use

Open the app on both machines on the same network. Tap a device, pick files.

- Folder icon sends a folder as a zip
- Paste icon sends clipboard text, or an image if there is no text
- On Windows you can drop files or folders onto the window
- History is the clock in the toolbar
- Received files go to Downloads/SendTo unless you change the folder in Settings
- Theme: System, Light, Dark, or OLED

## Advanced

Settings → Advanced. Leave it off unless you need it.

- **Require PIN to receive** — off by default. The other machine types the PIN shown on this one.
- **Add a host** — name, Tailscale address, or IP, when the device list cannot see the other machine. SendTo must already be open there. Port 47822.

Both sides should run the same version if you use PIN or Add host.

## Install

Releases: https://github.com/crashpoum/sendto/releases

- Windows: `SendTo-Setup-x.y.z.exe`
- Android: `app-release.apk` (sideload)

## Build

flutter pub get
dart run flutter_launcher_icons
flutter build windows --release --no-tree-shake-icons
flutter build apk --release --no-tree-shake-icons

Windows installer script is installer/sendto.iss (Inno Setup).

## License

MIT
