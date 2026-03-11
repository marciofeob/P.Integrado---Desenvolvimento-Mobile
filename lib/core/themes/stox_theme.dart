import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StoxTheme {
  static const Color sapBlue = Color(0xFF0A6ED1);
  static const Color sapDarkBlue = Color(0xFF0854A0);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: sapBlue,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA), // Um off-white leve para contraste
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: sapBlue,
        primary: sapBlue,
        secondary: sapDarkBlue,
        surface: Colors.white,
      ),

      // Ajuste global para que os campos de texto não fiquem colados
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: sapBlue, width: 2),
        ),
      ),

      // Botões "Blindados" para diferentes alturas de tela
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: sapBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54), // Um pouco mais alto para facilitar o toque
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          // Garante que o texto do botão não quebre em telas muito pequenas
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Estilização das Listas (ListTile) para o histórico e resultados
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.white,
      ),

      // AppBar consistente
      appBarTheme: const AppBarTheme(
        backgroundColor: sapBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light, // Garante legibilidade da barra de status
      ),
    );
  }
}