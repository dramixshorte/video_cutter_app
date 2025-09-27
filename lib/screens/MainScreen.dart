import 'package:flutter/material.dart';
import 'package:video_cutter_app/dashboard_screen.dart';
import 'package:video_cutter_app/screens/VideoCutterScreen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    Center(child: Text('قريباً - شاشة المسلسلات')),
    VideoCutterScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: SafeArea(child: _buildCustomNavigationBar()),
    );
  }

  Widget _buildCustomNavigationBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Color(0xFF1E1E2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.dashboard_rounded,
            label: 'لوحة التحكم',
            index: 0,
          ),
          _buildNavItem(
            icon: Icons.movie_creation_rounded,
            label: 'المسلسلات',
            index: 1,
          ),
          _buildNavItem(
            icon: Icons.video_library_rounded,
            label: 'قص الفيديو',
            index: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? Color.fromARGB(255, 253, 4, 141).withOpacity(0.2)
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Color.fromARGB(255, 255, 99, 185)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Color.fromARGB(
                                255,
                                255,
                                99,
                                138,
                              ).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 24,
                  ),
                ),
                SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: Duration(milliseconds: 300),
                  style: TextStyle(
                    color: isSelected
                        ? Color.fromARGB(255, 255, 2, 57)
                        : Colors.white70,
                    fontSize: isSelected ? 12 : 11,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
