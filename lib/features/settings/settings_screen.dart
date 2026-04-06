import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pop_study/pop_models.dart';
import '../pop_study/pop_study_active_provider.dart';
import '../pop_study/pop_settings.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _newLimit = 20;
  int _intervalMinutes = PopSettings.defaultIntervalMinutes;
  int _popCount = PopSettings.defaultPopCount;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final newLimit = ref.read(newLimitProvider);
    final popSettings = ref.read(popSettingsProvider);
    _newLimit = newLimit;
    _intervalMinutes = popSettings.intervalMinutes;
    _popCount = popSettings.popCount;
  }

  @override
  Widget build(BuildContext context) {
    final newLimit = ref.watch(newLimitProvider);
    final popSettings = ref.watch(popSettingsProvider);
    final isActive = ref.watch(popStudyActiveProvider);

    if (!_isDirty) {
      _newLimit = newLimit;
      _intervalMinutes = popSettings.intervalMinutes;
      _popCount = popSettings.popCount;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const ClampingScrollPhysics(),
        children: [
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
                    onPressed: _newLimit > 1
                        ? () => setState(() {
                              _newLimit -= 1;
                              _isDirty = true;
                            })
                        : null,
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$_newLimit',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() {
                      _newLimit += 1;
                      _isDirty = true;
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('ポップ学習', style: Theme.of(context).textTheme.titleMedium),
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
                    onPressed: _intervalMinutes > PopSettings.minIntervalMinutes
                        ? () => setState(() {
                              _intervalMinutes -= 1;
                              _isDirty = true;
                            })
                        : null,
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$_intervalMinutes',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _intervalMinutes < PopSettings.maxIntervalMinutes
                        ? () => setState(() {
                              _intervalMinutes += 1;
                              _isDirty = true;
                            })
                        : null,
                  ),
                ],
              ),
            ),
          ),
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
                    onPressed: _popCount > PopSettings.minPopCount
                        ? () => setState(() {
                              _popCount -= 1;
                              _isDirty = true;
                            })
                        : null,
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$_popCount',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _popCount < PopSettings.maxPopCount
                        ? () => setState(() {
                              _popCount += 1;
                              _isDirty = true;
                            })
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('設定を保存しますか？'),
                      content: Text(
                        isActive
                            ? '学習中です。前回学習からの経過時間は維持したまま、以後は新しい間隔（$_intervalMinutes 分）を適用します。'
                            : '変更内容を保存します。',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('キャンセル'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('保存'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (!ok) return;

              ref.read(newLimitProvider.notifier).state = _newLimit;
              await ref
                  .read(popSettingsProvider.notifier)
                  .setIntervalMinutes(_intervalMinutes);
              await ref.read(popSettingsProvider.notifier).setPopCount(_popCount);
              _isDirty = false;
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('設定を保存しました')),
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
