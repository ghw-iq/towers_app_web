import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../providers/app_providers.dart';
import 'home/home_screen.dart';
import 'towers/towers_screen.dart';
import 'subscriptions/subscriptions_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    TowersScreen(),
    SubscriptionsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // فحص النسخ الاحتياطي التلقائي عند فتح التطبيق
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAutoBackupCheck();
    });
  }

  Future<void> _runAutoBackupCheck() async {
    final triggered = await ref.read(appServiceProvider).checkAndTriggerAutoBackup();
    if (triggered && mounted) {
      ref.invalidate(profileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('تم تنزيل النسخة الاحتياطية التلقائية للإكسل بنجاح'),
              ),
            ],
          ),
          backgroundColor: AppColors.paidGreen,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          elevation: 0,
          onDestinationSelected: (int index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.cell_tower, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.cell_tower, color: AppColors.primary),
              label: 'الأبراج',
            ),
            NavigationDestination(
              icon: Icon(Icons.monetization_on_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.monetization_on, color: AppColors.primary),
              label: 'الأرباح',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'الحساب',
            ),
          ],
        ),
      ),
    );
  }
}