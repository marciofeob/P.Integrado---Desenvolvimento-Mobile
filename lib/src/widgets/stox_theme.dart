import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// StoxTheme — Inspirado no SAP Fiori Horizon Design System
///
/// Referência: SAP Fiori for Android UI Kit (Figma)
/// https://www.figma.com/community/file/1231185534479977099
///
/// Paleta oficial SAP Fiori Horizon:
/// - Brand Blue:      #0A6ED1  (sapBrand)
/// - Shell Bar Blue:  #1B4FA8  (sapShellBar)
/// - Accent Blue:     #0070F2  (sapAccent)
/// - Success Green:   #188918  (sapSuccess)
/// - Warning Amber:   #E9730C  (sapWarning)
/// - Error Red:       #BB0000  (sapError)
/// - Info Cyan:       #0070F2  (sapInfo)
/// - Neutral BG:      #F5F6F7  (sapBackground)
/// - Shell BG:        #FAFAFA  (sapSurface)
/// - Border:          #C0C2C4  (sapBorder)
/// - Text Primary:    #1D2D3E  (sapTextPrimary)
/// - Text Secondary:  #556B82  (sapTextSecondary)
/// - Text Disabled:   #89919A  (sapTextDisabled)

class StoxTheme {
  // ─── PALETA SAP FIORI HORIZON ───────────────────────────────────────────────

  /// Azul principal da marca SAP
  static const Color sapBrand = Color(0xFF0A6ED1);

  /// Azul escuro do Shell/AppBar SAP
  static const Color sapShellBar = Color(0xFF1B4FA8);

  /// Azul de destaque para links e ações secundárias
  static const Color sapAccent = Color(0xFF0070F2);

  // Status
  static const Color sapSuccess = Color(0xFF188918);
  static const Color sapSuccessBackground = Color(0xFFF1FDF6);
  static const Color sapWarning = Color(0xFFE9730C);
  static const Color sapWarningBackground = Color(0xFFFEF7F1);
  static const Color sapError = Color(0xFFBB0000);
  static const Color sapErrorBackground = Color(0xFFFFF1F1);
  static const Color sapInfo = Color(0xFF0070F2);
  static const Color sapInfoBackground = Color(0xFFF0F7FF);

  // Superfícies
  static const Color sapBackground = Color(0xFFF5F6F7);
  static const Color sapSurface = Color(0xFFFFFFFF);
  static const Color sapSurfaceElevated = Color(0xFFFAFAFA);

  // Bordas
  static const Color sapBorder = Color(0xFFC0C2C4);
  static const Color sapBorderStrong = Color(0xFF89919A);

  // Tipografia
  static const Color sapTextPrimary = Color(0xFF1D2D3E);
  static const Color sapTextSecondary = Color(0xFF556B82);
  static const Color sapTextDisabled = Color(0xFF89919A);
  static const Color sapTextInverted = Color(0xFFFFFFFF);
  static const Color sapTextLink = Color(0xFF0A6ED1);

  // Manter compatibilidade com código existente
  static const Color sapBlue = sapBrand;
  static const Color sapDarkBlue = sapShellBar;

  // ─── TIPOGRAFIA SAP 72 ──────────────────────────────────────────────────────
  // A fonte SAP 72 é proprietária. Usamos fallback para o padrão do sistema
  // (Roboto no Android), que é a abordagem recomendada pela própria SAP para
  // apps mobile de terceiros que seguem as guidelines do Fiori.
  // Para usar SAP 72: adicione o .ttf em assets/fonts/ e declare no pubspec.yaml

  static const String _fontFamily = 'Roboto'; // trocar por 'SAP72' se disponível

  static TextTheme get _textTheme => const TextTheme(
    // Display (títulos grandes)
    displayLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 32,
      fontWeight: FontWeight.w300,
      letterSpacing: -0.5,
      color: sapTextPrimary,
    ),
    displayMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 28,
      fontWeight: FontWeight.w300,
      color: sapTextPrimary,
    ),

    // Headlines (títulos de seção)
    headlineLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: sapTextPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: sapTextPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: sapTextPrimary,
    ),

    // Title (cabeçalhos de card/tile)
    titleLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: sapTextPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: sapTextPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: sapTextPrimary,
    ),

    // Body (texto corrido)
    bodyLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: sapTextPrimary,
    ),
    bodyMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: sapTextPrimary,
    ),
    bodySmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: sapTextSecondary,
    ),

    // Label (botões e chips)
    labelLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: sapTextInverted,
    ),
    labelMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: sapTextPrimary,
    ),
    labelSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: sapTextSecondary,
    ),
  );

  // ─── TEMA PRINCIPAL ─────────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      textTheme: _textTheme,

      // ── Cores base ──
      primaryColor: sapBrand,
      scaffoldBackgroundColor: sapBackground,

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
        outlineVariant: Color(0xFFE5E7E9),
        surfaceContainerHighest: sapSurfaceElevated,
        inversePrimary: Color(0xFF96C8FF),
      ),

      // ── AppBar — SAP Shell Bar ──
      // O Shell Bar do Fiori usa fundo azul escuro (#1B4FA8) com texto branco
      appBarTheme: const AppBarTheme(
        backgroundColor: sapShellBar,
        foregroundColor: sapTextInverted,
        centerTitle: true,
        elevation: 0,
        shadowColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: sapTextInverted,
          letterSpacing: 0.15,
        ),
        iconTheme: IconThemeData(
          color: sapTextInverted,
          size: 24,
        ),
        actionsIconTheme: IconThemeData(
          color: sapTextInverted,
          size: 24,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: sapSurface,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),

      // ── ElevatedButton — Fiori "Emphasized" Button ──
      // Fiori: fundo azul sólido, texto branco, bordas arredondadas (8px)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: sapBrand,
          foregroundColor: sapTextInverted,
          disabledBackgroundColor: const Color(0xFFE5E7E9),
          disabledForegroundColor: sapTextDisabled,
          minimumSize: const Size(double.infinity, 44),
          // Fiori usa 44dp como altura mínima de toque (Apple HIG / Material)
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            // Fiori usa 8px de raio — mais quadrado que o Material padrão
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ── OutlinedButton — Fiori "Standard" Button ──
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
            fontFamily: _fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ── TextButton — Fiori "Ghost" Button ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: sapBrand,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── TextField — Fiori Form Field ──
      // Fiori usa borda inferior visível (underline) ou borda completa
      // Para ambiente mobile industrial, mantemos a borda completa
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: sapSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: sapTextSecondary,
          fontWeight: FontWeight.w400,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          color: sapBrand,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: sapTextDisabled,
        ),
        helperStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          color: sapTextSecondary,
        ),
        errorStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          color: sapError,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: sapBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: sapBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: sapBrand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: sapError, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: sapError, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7E9), width: 1),
        ),
      ),

      // ── Card — Fiori Object List Item ──
      cardTheme: CardThemeData(
        color: sapSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE5E7E9), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // ── ListTile — Fiori List Item ──
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        minLeadingWidth: 24,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: sapTextPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: sapTextSecondary,
        ),
        iconColor: sapBrand,
      ),

      // ── Divider ──
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7E9),
        thickness: 1,
        space: 1,
      ),

      // ── Chip — Fiori Token ──
      chipTheme: ChipThemeData(
        backgroundColor: sapInfoBackground,
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: sapTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: sapBorder, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // ── SnackBar — Fiori Message Strip ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: sapTextInverted,
        ),
      ),

      // ── Dialog — Fiori Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: sapSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: sapTextPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: sapTextPrimary,
        ),
      ),

      // ── Switch ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return sapBrand;
          return const Color(0xFF89919A);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return sapBrand.withAlpha(77);
          }
          return const Color(0xFFE5E7E9);
        }),
      ),

      // ── Drawer ──
      drawerTheme: const DrawerThemeData(
        backgroundColor: sapSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(0),
            bottomRight: Radius.circular(0),
          ),
        ),
      ),

      // ── ProgressIndicator ──
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: sapBrand,
        linearTrackColor: Color(0xFFD1E8FF),
        circularTrackColor: Color(0xFFD1E8FF),
      ),

      // ── FloatingActionButton ──
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: sapBrand,
        foregroundColor: sapTextInverted,
        elevation: 2,
        shape: CircleBorder(),
      ),
    );
  }

  // ─── HELPERS ESTÁTICOS ──────────────────────────────────────────────────────
  // Utilitários para usar as cores SAP em widgets customizados

  /// Retorna a cor de fundo do status badge baseado no syncStatus do SQLite
  /// 0 = Pendente, 1 = Sincronizado, 2 = Erro
  static Color syncStatusColor(int status) {
    switch (status) {
      case 1:
        return sapSuccess;
      case 2:
        return sapError;
      default:
        return sapWarning;
    }
  }

  /// Retorna a cor de fundo do banner de status
  static Color syncStatusBackground(int status) {
    switch (status) {
      case 1:
        return sapSuccessBackground;
      case 2:
        return sapErrorBackground;
      default:
        return sapWarningBackground;
    }
  }

  /// Retorna o ícone do status de sincronização
  static IconData syncStatusIcon(int status) {
    switch (status) {
      case 1:
        return Icons.cloud_done_rounded;
      case 2:
        return Icons.cloud_off_rounded;
      default:
        return Icons.cloud_upload_rounded;
    }
  }

  /// Retorna o texto do status de sincronização
  static String syncStatusLabel(int status) {
    switch (status) {
      case 1:
        return 'Sincronizado';
      case 2:
        return 'Erro no Envio';
      default:
        return 'Pendente';
    }
  }
}