import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint('❌ ERROR: Variables .env no cargadas');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;

    switch (event) {
      case AuthChangeEvent.initialSession:
        debugPrint('📢 Auth Event: Initial Session');
        break;
      case AuthChangeEvent.signedIn:
        debugPrint('✅ Auth Event: User Logged In');
        break;
      case AuthChangeEvent.signedOut:
        debugPrint('🚪 Auth Event: User Logged Out');
        break;
      case AuthChangeEvent.passwordRecovery:
        debugPrint('🔐 Auth Event: Password Recovery');
        break;
      case AuthChangeEvent.tokenRefreshed:
        debugPrint('♻️ Auth Event: Token Refreshed');
        break;
      case AuthChangeEvent.userUpdated:
        debugPrint('🔄 Auth Event: User Updated');
        break;
      case AuthChangeEvent.userDeleted:
        debugPrint('🗑️ Auth Event: User Deleted');
        break;
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Aplicación BLE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
