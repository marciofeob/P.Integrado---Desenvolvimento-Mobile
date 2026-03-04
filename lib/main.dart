import 'package:flutter/material.dart';
import 'dart:io'; // Importante para o HttpOverrides
import 'features/auth/login_page.dart';

// =======================================================
// ISSO FAZ O APP IGNORAR CERTIFICADOS SSL INVÁLIDOS (Igual o Postman)
// =======================================================
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  // Ativa a liberação do SSL antes de o app iniciar
  HttpOverrides.global = MyHttpOverrides();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contagem de Estoque',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A6ED1)),
        useMaterial3: true,
      ),
      // Inicia direto na tela de Login
      home: const LoginPage(), 
    );
  }
}