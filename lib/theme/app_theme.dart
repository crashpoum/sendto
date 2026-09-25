import 'package:flutter/material.dart';

enum AppThemeMode { system, light, dark, oled }

class AppTheme {
  static const canvasLight = Color(0xFFF3F4F6);
  static const cardLight = Color(0xFFFFFFFF);
  static const inkLight = Color(0xFF111111);
  static const mutedLight = Color(0xFF6B6B6B);
  static const lineLight = Color(0xFFE6E6E8);

  static const canvasDark = Color(0xFF0E0E10);
  static const cardDark = Color(0xFF1C1C1E);
  static const inkDark = Color(0xFFF2F2F2);
  static const mutedDark = Color(0xFFA1A1A1);
  static const lineDark = Color(0xFF2A2A2C);

  static const canvasOled = Color(0xFF000000);
  static const cardOled = Color(0xFF000000);
  static const inkOled = Color(0xFFF5F5F5);
  static const mutedOled = Color(0xFF8E8E8E);
  static const lineOled = Color(0xFF1A1A1A);

  static const live = Color(0xFF22C55E);
  static const action = Color(0xFF111111);

  static ThemeData light() => _build(
        brightness: Brightness.light,
        canvas: canvasLight,
        card: cardLight,
        ink: inkLight,
        muted: mutedLight,
        line: lineLight,
        useCards: true,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        canvas: canvasDark,
        card: cardDark,
        ink: inkDark,
        muted: mutedDark,
        line: lineDark,
        useCards: true,
      );

  static ThemeData oled() => _build(
        brightness: Brightness.dark,
        canvas: canvasOled,
        card: cardOled,
        ink: inkOled,
        muted: mutedOled,
        line: lineOled,
        useCards: false,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color canvas,
    required Color card,
    required Color ink,
    required Color muted,
    required Color line,
    required bool useCards,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: ink,
      onPrimary: brightness == Brightness.light ? Colors.white : canvas,
      secondary: live,
      onSecondary: Colors.black,
      error: const Color(0xFFDC2626),
      onError: Colors.white,
      surface: card,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      dividerColor: line,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: ink.withValues(alpha: 0.04),
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          color: ink,
          height: 1.05,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: ink,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: muted,
        ),
      ),
      iconTheme: IconThemeData(color: ink, size: 22),
      extensions: [
        SendToTheme(
          canvas: canvas,
          card: card,
          ink: ink,
          muted: muted,
          line: line,
          live: live,
          useCards: useCards,
        ),
      ],
    );
  }
}

@immutable
class SendToTheme extends ThemeExtension<SendToTheme> {
  const SendToTheme({
    required this.canvas,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.live,
    required this.useCards,
  });

  final Color canvas;
  final Color card;
  final Color ink;
  final Color muted;
  final Color line;
  final Color live;
  final bool useCards;

  static SendToTheme of(BuildContext context) =>
      Theme.of(context).extension<SendToTheme>()!;

  @override
  SendToTheme copyWith({
    Color? canvas,
    Color? card,
    Color? ink,
    Color? muted,
    Color? line,
    Color? live,
    bool? useCards,
  }) {
    return SendToTheme(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      live: live ?? this.live,
      useCards: useCards ?? this.useCards,
    );
  }

  @override
  SendToTheme lerp(ThemeExtension<SendToTheme>? other, double t) {
    if (other is! SendToTheme) return this;
    return SendToTheme(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      live: Color.lerp(live, other.live, t)!,
      useCards: t < 0.5 ? useCards : other.useCards,
    );
  }
}
