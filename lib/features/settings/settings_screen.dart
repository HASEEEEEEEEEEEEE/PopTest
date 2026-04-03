import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/router.dart';

/// Settings screen placeholder.
/// TODO: implement user preferences (notification schedule, theme, etc.).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.home)),
      ),
      body: const Center(child: Text('Settings (placeholder)')),
    );
  }
}
