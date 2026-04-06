import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/pop_study/pop_monitoring_provider.dart';
import 'routing/router.dart';

class PopTestApp extends ConsumerWidget {
  const PopTestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(popMonitoringProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'PopTest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) =>
              ref.read(popActivityProvider.notifier).record(),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
