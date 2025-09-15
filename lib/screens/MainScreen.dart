import 'package:flutter/material.dart';
import 'package:video_cutter_app/dashboard_screen.dart';
import 'package:video_cutter_app/screens/SeriesDetailsScreen.dart';
import 'package:video_cutter_app/screens/VideoCutterScreen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const SeriesListScreen(),
    const VideoCutterScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.local_movies), // ✅ اسم أيقونة صحيح
            label: 'المسلسلات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: 'قص الفيديو',
          ),
        ],
      ),
    );
  }
}