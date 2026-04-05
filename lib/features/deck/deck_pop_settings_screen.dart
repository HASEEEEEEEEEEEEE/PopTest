import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pop_study/deck_pop_settings.dart';
import '../pop_study/pop_models.dart';

class DeckPopSettingsScreen extends ConsumerWidget {
  const DeckPopSettingsScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(deckPopSettingsProvider(deckId));
    final notifier = ref.read(deckPopSettingsProvider(deckId).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('デッキ別ポップ設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('全体設定を使う'),
              subtitle: const Text('OFFでこのデッキだけ個別設定を使います'),
              value: settings.useGlobal,
              onChanged: notifier.setUseGlobal,
            ),
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: settings.useGlobal ? 0.5 : 1,
            child: IgnorePointer(
              ignoring: settings.useGlobal,
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('対象サービス'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: PopService.values
                                .map((service) => FilterChip(
                                      label: Text(service.label),
                                      selected:
                                          settings.services.contains(service),
                                      onSelected: (_) =>
                                          notifier.toggleService(service),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      title: const Text('出題間隔（分）'),
                      subtitle: Text(
                          '${PopSettings.minIntervalMinutes}〜${PopSettings.maxIntervalMinutes}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed:
                                settings.intervalMinutes > PopSettings.minIntervalMinutes
                                    ? () => notifier.setIntervalMinutes(
                                        settings.intervalMinutes - 1)
                                    : null,
                          ),
                          Text('${settings.intervalMinutes}'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed:
                                settings.intervalMinutes < PopSettings.maxIntervalMinutes
                                    ? () => notifier.setIntervalMinutes(
                                        settings.intervalMinutes + 1)
                                    : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      title: const Text('1回の問題数'),
                      subtitle: Text(
                          '${PopSettings.minPopCount}〜${PopSettings.maxPopCount}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: settings.popCount > PopSettings.minPopCount
                                ? () => notifier.setPopCount(settings.popCount - 1)
                                : null,
                          ),
                          Text('${settings.popCount}'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: settings.popCount < PopSettings.maxPopCount
                                ? () => notifier.setPopCount(settings.popCount + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
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
