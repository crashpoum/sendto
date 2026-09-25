import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'app_controller.dart';
import 'theme/theme_controller.dart';
import 'ui/home_page.dart';
import 'ui/used_icons.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(980, 680),
      minimumSize: Size(720, 520),
      title: 'SendTo',
      backgroundColor: Colors.transparent,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final themes = ThemeController();
  final app = AppController();
  await themes.load();
  await app.start();

  WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
    themes.notifyListeners();
  };

  runApp(SendToApp(themes: themes, app: app));
}

class SendToApp extends StatelessWidget {
  const SendToApp({
    super.key,
    required this.themes,
    required this.app,
  });

  final ThemeController themes;
  final AppController app;

  // Keep Material glyphs in the release font.
  static const icons = kUsedIcons;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themes,
      builder: (context, _) {
        final platform =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final theme = themes.themeFor(platform);
        return MaterialApp(
          title: 'SendTo',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: HomePage(app: app, themes: themes),
        );
      },
    );
  }
}
