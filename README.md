 (cd "$(git rev-parse --show-toplevel)" && git apply --3way <<'EOF' 
diff --git a/README.md b/README.md
index 2c8a8aef4b72bc49957d646b6125d6b2ff7d8fec..d11af49750266b6cf8322b508690dd9cafbbbd8d 100644
--- a/README.md
+++ b/README.md
@@ -1,16 +1,34 @@
-# flutter_application_1
+# Growee BLE Manager
 
-A new Flutter project.
+Aplicación Flutter para gestionar dispositivos Growee mediante Bluetooth Low Energy (BLE) y supervisar flujos de alta en instalaciones hidropónicas y de riego inteligente. Desde la app puedes emparejar controladores, consultar su estado y ajustar los parámetros críticos sin cables.
 
-## Getting Started
+## Introducción
 
-This project is a starting point for a Flutter application.
+El proyecto organiza la lógica de conexión BLE en torno a rutas claramente definidas y una capa de servicios reutilizable. La experiencia guía al usuario desde una pantalla inicial de diagnóstico hacia la consola principal, donde se visualizan métricas de alto caudal y se administran los dispositivos vinculados. La navegación está preparada para ampliarse con nuevas pantallas de monitoreo o automatización.
 
-A few resources to get you started if this is your first Flutter project:
+## Configuración rápida
 
-- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
-- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
+### Dependencias clave
 
-For help getting started with Flutter development, view the
-[online documentation](https://docs.flutter.dev/), which offers tutorials,
-samples, guidance on mobile development, and a full API reference.
+- **Flutter SDK** (3.x o superior) y herramientas de línea de comando.
+- Paquetes `flutter_blue_plus` para el escaneo y la conexión BLE, y `logger` para el registro de eventos.
+- Dispositivo Android o iOS con Bluetooth y localización habilitados.
+
+### Rutas principales
+
+- `/` → `SplashScreen`: verificación inicial de estado de la app.
+- `/home` → `HomeScreen`: panel principal con el resumen de flujos de alta y dispositivos activos.
+- `/add-device` → `AddDevicePage`: asistente paso a paso para emparejar controladores Growee por BLE.
+
+### Cómo ejecutar
+
+```bash
+flutter pub get
+flutter run
+```
+
+Puedes especificar un dispositivo con `-d <id>` para probar directamente en hardware BLE.
+
+### Pantalla de emparejamiento y permisos
+
+La pantalla de emparejamiento solicita permisos de Bluetooth y ubicación en tiempo de ejecución mediante `BleService`. Asegúrate de que el `AndroidManifest.xml` y el `Info.plist` incluyan los permisos BLE y descripciones de uso antes de compilar, y de que el usuario tenga el Bluetooth activado durante el proceso de escaneo.
 
EOF
)