import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../../directory/presentation/screens/directory_screen.dart';
import '../../../education/presentation/screens/education_screen.dart';
import '../../../emergency/presentation/screens/emergency_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _sectionCount = 4;

  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = _normalizeIndex(widget.initialIndex);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = _normalizeIndex(widget.initialIndex);
    }
  }

  int _normalizeIndex(int index) {
    if (index < 0 || index >= _sectionCount) {
      return 0;
    }

    return index;
  }

  void _navigateTo(int index) {
    setState(() => _currentIndex = _normalizeIndex(index));
  }

  @override
  Widget build(BuildContext context) {
    const screens = <Widget>[
      EmergencyScreen(isEmbedded: true),
      EducationScreen(isEmbedded: true),
      DirectoryScreen(isEmbedded: true),
      ProfileScreen(isEmbedded: true),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.chatbot),
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Chat'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _navigateTo,
      ),
    );
  }
}
