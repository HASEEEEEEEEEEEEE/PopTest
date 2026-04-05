import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pop_study/pop_models.dart';
import '../pop_study/pop_settings.dart';
import 'settings_providers.dart';

/// Settings screen with adjustable session parameters.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newLimit = ref.watch(newLimitProvider);
    final popSettings = ref.watch(popSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const ClampingScrollPhysics(),
        children: [
          // ── 通常学習 ──────────────────────────────────────────────────────
          Text('通常学習', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('新規カード上限 (1セッション)'),
                        Text(
                          'セッションごとに学習する新規カードの最大枚数',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: newLimit > 1
                        ? () => ref
                            .read(newLimitProvider.notifier)
                            .state = newLimit - 1
                        : null,
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$newLimit',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => ref
                        .read(newLimitProvider.notifier)
                        .state = newLimit + 1,
                  ),
                ],
              ),
            ),
          ),

          // ── ポップ学習 ────────────────────────────────────────────────────
          const SizedBox(height: 24),
          Text('ポップ学習', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          // 出題頻度
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('出題頻度（分間隔）'),
                        Text(
                          'ポップ学習を表示する間隔（${PopSettings.minIntervalMinutes}〜${PopSettings.maxIntervalMinutes}分）',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: popSettings.intervalMinutes >
                            PopSettings.minIntervalMinutes
                        ? () => ref
                            .read(popSettingsProvider.notifier)
                            .setIntervalMinutes(
                                popSettings.intervalMinutes - 1)
                        : null,
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${popSettings.intervalMinutes}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: popSettings.intervalMinutes <
                            PopSettings.maxIntervalMinutes
                        ? () => ref
                            .read(popSettingsProvider.notifier)
                            .setIntervalMinutes(
                                popSettings.intervalMinutes + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 1回の問題数
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1回に出す問題数'),
                        Text(
                          'ポップ学習1回あたりの問題数（${PopSettings.minPopCount}〜${PopSettings.maxPopCount}問）',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed:
                        popSettings.popCount > PopSettings.minPopCount
                            ? () => ref
                                .read(popSettingsProvider.notifier)
                                .setPopCount(popSettings.popCount - 1)
                            : null,
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${popSettings.popCount}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed:
                        popSettings.popCount < PopSettings.maxPopCount
                            ? () => ref
                                .read(popSettingsProvider.notifier)
                                .setPopCount(popSettings.popCount + 1)
                            : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
