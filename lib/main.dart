import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necessário para configurar o estilo da barra do sistema
import 'dart:io';
import 'features/auth/login_page.dart';

// Sobrescrita para aceitar certificados SSL auto-assinados (SAP Service Layer)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  // Garante que o Flutter esteja inicializado antes de rodar configurações de sistema
  WidgetsFlutterBinding.ensureInitialized();
  
  // Resolve o problema de certificados para o SAP
  HttpOverrides.global = MyHttpOverrides();

  // Força a orientação vertical (opcional, mas recomendado para apps de estoque)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Define a cor da barra de status e da barra de navegação do Android
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // Deixa a barra de status transparente
    statusBarIconBrightness: Brightness.light, // Ícones claros (wifi, bateria)
    systemNavigationBarColor: Colors.white, // Cor da barra de navegação inferior
    systemNavigationBarIconBrightness: Brightness.dark, // Ícones da barra inferior escuros
  ));

  runApp(const StoxApp());
}

class StoxApp extends StatelessWidget {
  const StoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0A6ED1);

    return MaterialApp(
      title: 'STOX - Inventário',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
        ),
        primaryColor: primaryColor,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        
        // Configuração global para AppBars
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.light, // Garante legibilidade no topo
        ),

        // Padronização de botões para evitar cortes em telas pequenas
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48), // Garante uma área de toque boa
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),

        // Configuração de inputs (melhorado para preencher a tela corretamente)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: primaryColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          labelStyle: const TextStyle(color: Colors.blueGrey),
        ),
      ),
      // O uso do builder aqui ajuda a aplicar o SafeArea globalmente se necessário
      home: const LoginPage(),
    );
  }
}