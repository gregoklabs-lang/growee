import 'package:flutter/material.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/devices/add_device_page.dart';

class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const addDevice = '/add-device';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        home: (context) => const HomeScreen(),
        addDevice: (context) => const AddDevicePage(),
      };
}
