import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tema visual do STOX inspirado no SAP Fiori Horizon Design System.
///
/// Referência: SAP Fiori for Android UI Kit (Figma)
/// https://www.figma.com/community/file/1231185534479977099
///
/// Fonte: a SAP 72 é proprietária. O app usa Roboto como fallback —
/// abordagem recomendada pela SAP para apps mobile de terceiros.
/// Para usar SAP 72, adicione o .ttf em `assets/fonts/` e declare no `pubspec.yaml`.
///
/// Estrutura:
/// - Paleta de cores SAP Fiori Horizon (constantes estáticas)
/// - Tipografia (TextTheme com hierarquia completa)
/// - Tema [lightTheme] com todos os componentes Material 3
/// - Helpers de status de sincronização (cor, ícone, rótulo)
class StoxTheme {
  StoxTheme._();

  // ── Paleta SAP Fiori Horizon ──────────────────────────────────────────────

  /// Azul principal — identidade visual SAP.
  static const Color sapBrand = Color(0xFF0A6ED1);

  /// Azul escuro para AppBar / Shell Bar.
  static const Color sapShellBar = Color(0xFF1B4FA8);

  /// Azul para links e ações secundárias.
  static const Color sapAccent = Color(0xFF0070F2);

  // ── Status semânticos ───────────────────────────────────────────────────

  static const Color sapSuccess = Color(0xFF188918);
  static const Color sapSuccessBackground = Color(0xFFF1FDF6);
  static const Color sapWarning = Color(0xFFE9730C);
  static const Color sapWarningBackground = Color(0xFFFEF7F1);
  static const Color sapError = Color(0xFFBB0000);
  static const Color sapErrorBackground = Color(0xFFFFF1F1);
  static const Color sapInfo = Color(0xFF0070F2);
  static const Color sapInfoBackground = Color(0xFFF0F7FF);

  // ── Superfícies ───────────────────────────────────────────────────────────

  static const Color sapBackground = Color(0xFFF5F6F7);
  static const Color sapSurface = Color(0xFFFFFFFF);
  static const Color sapSurfaceElevated = Color(0xFFFAFAFA);

  // ── Bordas ────────────────────────────────────────────────────────────────

  static const Color sapBorder = Color(0xFFC0C2C4);
  static const Color sapBorderStrong = Color(0xFF89919A);
  static const Color _sapBorderLight = Color(0xFFE5E7E9);

  // ── Texto ─────────────────────────────────────────────────────────────────

  static const Color sapTextPrimary = Color(0xFF1D2D3E);
  static const Color sapTextSecondary = Color(0xFF556B82);
  static const Color sapTextDisabled = Color(0xFF89919A);
  static const Color sapTextInverted = Color(0xFFFFFFFF);
  static const Color sapTextLink = Color(0xFF0A6ED1);

  // ── Aliases de compatibilidade ────────────────────────────────────────────

  /// Alias para [sapBrand]. Mantido para compatibilidade com código legado.
  static const Color sapBlue = sapBrand;

  /// Alias para [sapShellBar]. Mantido para compatibilidade com código legado.
  static const Color sapDarkBlue = sapShellBar;

  // ── Tipografia ────────────────────────────────────────────────────────────

  /// Trocar por `'SAP72'` quando a fonte estiver disponível nos assets.
  static const String _font = 'Roboto';

  static TextTheme get _textTheme => const TextTheme(
        displayLarge: TextStyle(
          fontFamily: _font, fontSize: 32,
          fontWeight: FontWeight.w300, letterSpacing: -0.5,
          color: sapTextPrimary,
        ),
        displayMedium: TextStyle(
          fontFamily: _font, fontSize: 28,
          fontWeight: FontWeight.w300, color: sapTextPrimary,
        ),
        headlineLarge: TextStyle(
          fontFamily: _font, fontSize: 24,
          fontWeight: FontWeight.w600, color: sapTextPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: _font, fontSize: 20,
          fontWeight: FontWeight.w600, color: sapTextPrimary,
        ),
        headlineSmall: TextStyle(
          fontFamily: _font, fontSize: 18,
          fontWeight: FontWeight.w600, color: sapTextPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: _font, fontSize: 16,
          fontWeight: FontWeight.w600, color: sapTextPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: _font, fontSize: 15,
          fontWeight: FontWeight.w500, color: sapTextPrimary,
        ),
        titleSmall: TextStyle(
          fontFamily: _font, fontSize: 14,
          fontWeight: FontWeight.w500, color: sapTextPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: _font, fontSize: 15,
          fontWeight: FontWeight.w400, color: sapTextPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: _font, fontSize: 14,
          fontWeight: FontWeight.w400, color: sapTextPrimary,
        ),
        bodySmall: TextStyle(
          fontFamily: _font, fontSize: 12,
          fontWeight: FontWeight.w400, color: sapTextSecondary,
        ),
        labelLarge: TextStyle(
          fontFamily: _font, fontSize: 14,
          fontWeight: FontWeight.w700, letterSpacing: 0.5,
          color: sapTextInverted,
        ),
        labelMedium: TextStyle(
          fontFamily: _font, fontSize: 12,
          fontWeight: FontWeight.w600, color: sapTextPrimary,
        ),
        labelSmall: TextStyle(
          fontFamily: _font, fontSize: 11,
          fontWeight: FontWeight.w500, color: sapTextSecondary,
        ),
      );

  // ── Tema principal ────────────────────────────────────────────────────────

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: _font,
        textTheme: _textTheme,
        primaryColor: sapBrand,
        scaffoldBackgroundColor: sapBackground,

        // ── Color Scheme ──
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: sapBrand,
          onPrimary: sapTextInverted,
          primaryContainer: Color(0xFFD1E8FF),
          onPrimaryContainer: sapShellBar,
          secondary: sapShellBar,
          onSecondary: sapTextInverted,
          secondaryContainer: Color(0xFFD1DCF5),
          onSecondaryContainer: Color(0xFF0A2A6A),
          tertiary: sapAccent,
          onTertiary: sapTextInverted,
          error: sapError,
          onError: sapTextInverted,
          errorContainer: sapErrorBackground,
          onErrorContainer: sapError,
          surface: sapSurface,
          onSurface: sapTextPrimary,
          onSurfaceVariant: sapTextSecondary,
          outline: sapBorder,
          outlineVariant: _sapBorderLight,
          surfaceContainerHighest: sapSurfaceElevated,
          inversePrimary: Color(0xFF96C8FF),
        ),

        // ── SAP Shell Bar ──
        appBarTheme: const AppBarTheme(
          backgroundColor: sapShellBar,
          foregroundColor: sapTextInverted,
          centerTitle: true,
          elevation: 0,
          shadowColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontFamily: _font,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: sapTextInverted,
            letterSpacing: 0.15,
          ),
          iconTheme: IconThemeData(color: sapTextInverted, size: 24),
          actionsIconTheme: IconThemeData(color: sapTextInverted, size: 24),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: sapSurface,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        ),

        // ── Fiori "Emphasized" Button ──
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: sapBrand,
            foregroundColor: sapTextInverted,
            disabledBackgroundColor: _sapBorderLight,
            disabledForegroundColor: sapTextDisabled,
            minimumSize: const Size(double.infinity, 44),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontFamily: _font, fontSize: 14,
              fontWeight: FontWeight.w700, letterSpacing: 0.5,
            ),
          ),
        ),

        // ── Fiori "Standard" Button ──
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: sapBrand,
            disabledForegroundColor: sapTextDisabled,
            minimumSize: const Size(double.infinity, 44),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            side: const BorderSide(color: sapBrand, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontFamily: _font, fontSize: 14,
              fontWeight: FontWeight.w600, letterSpacing: 0.5,
            ),
          ),
        ),

        // ── Fiori "Ghost" Button ──
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: sapBrand,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Fiori Form Field ──
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: sapSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 14,
          ),
          labelStyle: const TextStyle(
            fontFamily: _font, fontSize: 14,
            color: sapTextSecondary, fontWeight: FontWeight.w400,
          ),
          floatingLabelStyle: const TextStyle(
            fontFamily: _font, fontSize: 12,
            color: sapBrand, fontWeight: FontWeight.w600,
          ),
          hintStyle: const TextStyle(
            fontFamily: _font, fontSize: 14, color: sapTextDisabled,
          ),
          helperStyle: const TextStyle(
            fontFamily: _font, fontSize: 12, color: sapTextSecondary,
          ),
          errorStyle: const TextStyle(
            fontFamily: _font, fontSize: 12, color: sapError,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: sapBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: sapBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: sapBrand, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: sapError),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: sapError, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _sapBorderLight),
          ),
        ),

        // ── Fiori Object List Item ──
        cardTheme: CardThemeData(
          color: sapSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: _sapBorderLight),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
        ),

        // ── Fiori List Item ──
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          minLeadingWidth: 24,
          iconColor: sapBrand,
          titleTextStyle: TextStyle(
            fontFamily: _font, fontSize: 15,
            fontWeight: FontWeight.w500, color: sapTextPrimary,
          ),
          subtitleTextStyle: TextStyle(
            fontFamily: _font, fontSize: 13,
            fontWeight: FontWeight.w400, color: sapTextSecondary,
          ),
        ),

        dividerTheme: const DividerThemeData(
          color: _sapBorderLight,
          thickness: 1,
          space: 1,
        ),

        // ── Fiori Token ──
        chipTheme: ChipThemeData(
          backgroundColor: sapInfoBackground,
          labelStyle: const TextStyle(
            fontFamily: _font, fontSize: 12,
            fontWeight: FontWeight.w500, color: sapTextPrimary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: sapBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),

        // ── Fiori Message Strip ──
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentTextStyle: const TextStyle(
            fontFamily: _font, fontSize: 14,
            fontWeight: FontWeight.w500, color: sapTextInverted,
          ),
        ),

        // ── Fiori Dialog ──
        dialogTheme: DialogThemeData(
          backgroundColor: sapSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          titleTextStyle: const TextStyle(
            fontFamily: _font, fontSize: 18,
            fontWeight: FontWeight.w600, color: sapTextPrimary,
          ),
          contentTextStyle: const TextStyle(
            fontFamily: _font, fontSize: 14,
            fontWeight: FontWeight.w400, color: sapTextPrimary,
          ),
        ),

        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? sapBrand
                : const Color(0xFF89919A),
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? sapBrand.withAlpha(77)
                : _sapBorderLight,
          ),
        ),

        drawerTheme: const DrawerThemeData(
          backgroundColor: sapSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),

        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: sapBrand,
          linearTrackColor: Color(0xFFD1E8FF),
          circularTrackColor: Color(0xFFD1E8FF),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: sapBrand,
          foregroundColor: sapTextInverted,
          elevation: 2,
          shape: CircleBorder(),
        ),
      );

  // ── Helpers de status de sincronização ─────────────────────────────────────

  /// Cor de destaque do badge de sincronização.
  ///
  /// `0` = Pendente (laranja), `1` = Sincronizado (verde), `2` = Erro (vermelho).
  static Color syncStatusColor(int status) => switch (status) {
        1 => sapSuccess,
        2 => sapError,
        _ => sapWarning,
      };

  /// Cor de fundo do banner de status.
  static Color syncStatusBackground(int status) => switch (status) {
        1 => sapSuccessBackground,
        2 => sapErrorBackground,
        _ => sapWarningBackground,
      };

  /// Ícone representativo do status de sincronização.
  static IconData syncStatusIcon(int status) => switch (status) {
        1 => Icons.cloud_done_rounded,
        2 => Icons.cloud_off_rounded,
        _ => Icons.cloud_upload_rounded,
      };

  /// Rótulo textual do status de sincronização.
  static String syncStatusLabel(int status) => switch (status) {
        1 => 'Sincronizado',
        2 => 'Erro no Envio',
        _ => 'Pendente',
      };
}