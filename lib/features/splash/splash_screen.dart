import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _imageLoaded = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Evita ejecutar el precache más de una vez
    if (!_initialized) {
      _initialized = true;

      // Precargar el logo de forma segura con el contexto disponible
      precacheImage(const AssetImage('assets/logo.png'), context).then((_) {
        setState(() => _imageLoaded = true);

        // Esperar 3 segundos y luego navegar al home
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedOpacity(
          opacity: _imageLoaded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 600),
          child: const Image(
            image: AssetImage('assets/logo.png'),
            width: 180,
            height: 180,
          ),
        ),
      ),
    );
  }
}
