import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'screens/dashboard_screen.dart';
import 'screens/buildings_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/reminders_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const BuildingsScreen(),
    const FinanceScreen(),
    const RemindersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.layoutDashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.home),
            label: 'Properties',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.indianRupee),
            label: 'Finance',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.bell),
            label: 'Reminders',
          ),
        ],
      ),
    );
  }
}
