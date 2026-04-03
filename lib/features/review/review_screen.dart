import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/router.dart';

/// Review (flashcard quiz) screen placeholder.
/// TODO: implement spaced-repetition review flow.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.home)),
      ),
      body: const Center(child: Text('Review (placeholder)')),
    );
  }
}
