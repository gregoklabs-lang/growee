import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../modify/modify_page.dart';
import '../history/history_page.dart';
import '../devices/devices_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      _buildDashboardPage(),
      const ModifyPage(),
      const HistoryPage(),
      const DevicesPage(),
    ]);
  }

  Widget _buildDashboardPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Dashboard Principal',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.login);
              },
              child: const Text('Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  final List<String> _titles = [
    'Dashboard',
    'Modify',
    'History',
    'Devices',
  ];

  final List<String> _icons = [
    'assets/icons/dashboard.png',
    'assets/icons/edit.png',
    'assets/icons/history.png',
    'assets/icons/devices.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: List.generate(_titles.length, (index) {
          return BottomNavigationBarItem(
            icon: Image.asset(
              _icons[index],
              width: 24,
              height: 24,
              color:
                  _currentIndex == index ? Colors.blueAccent : Colors.grey,
            ),
            label: _titles[index],
          );
        }),
      ),
    );
  }
}
