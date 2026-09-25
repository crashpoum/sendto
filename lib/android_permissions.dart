import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// One silent request pass on Android. No settings screen.
Future<void> requestAndroidPermissions() async {
  if (!Platform.isAndroid) return;

  await [
    Permission.nearbyWifiDevices,
    Permission.storage,
    Permission.photos,
    Permission.manageExternalStorage,
    Permission.notification,
  ].request();
}
