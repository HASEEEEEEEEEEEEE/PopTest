import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../monitoring/select_apps_screen.dart';
import '../pop_study/deck_pop_settings.dart';
import '../pop_study/native_pop_monitoring.dart';
import '../pop_study/pop_models.dart';

class DeckPopSettingsScreen extends ConsumerWidget {
  const DeckPopSettingsScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(deckPopSettingsProvider(deckId));
    final notifier = ref.read(deckPopSettingsProvider(deckId).notifier);
    final appsAsync = ref.watch(installedAppsProvider);
    final appsByPackage = appsAsync.valueOrNull != null
        ? {for (final a in appsAsync.value!) a.packageName: a}
        : <String, InstalledApp>{};

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
                  // ── 監視対象アプリ ──
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: const Text('監視対象'),
                          subtitle: Text(
                            settings.packageNames.isEmpty &&
                                    settings.customUrls.isEmpty
                                ? '未設定'
                                : 'アプリ ${settings.packageNames.length}件 / URL ${settings.customUrls.length}件',
                          ),
                          trailing: TextButton.icon(
                            onPressed: () => _openSelectApps(
                                context, ref, settings, notifier),
                            icon: const Icon(Icons.edit),
                            label: const Text('変更'),
                          ),
                        ),
                        if (settings.packageNames.isNotEmpty ||
                            settings.customUrls.isNotEmpty) ...[
                          const Divider(height: 1),
                          ...settings.packageNames.map((pkg) {
                            final app = appsByPackage[pkg];
                            return ListTile(
                              dense: true,
                              leading: app != null
                                  ? _AppIcon(app: app)
                                  : const Icon(Icons.apps),
                              title: Text(app?.label ?? pkg,
                                  style: const TextStyle(fontSize: 13)),
                            );
                          }),
                          ...settings.customUrls.map((url) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.language),
                                title: Text(url,
                                    style: const TextStyle(fontSize: 13)),
                              )),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── 出題間隔 ──
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
                            onPressed: settings.intervalMinutes >
                                    PopSettings.minIntervalMinutes
                                ? () => notifier.setIntervalMinutes(
                                    settings.intervalMinutes - 1)
                                : null,
                          ),
                          Text('${settings.intervalMinutes}'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: settings.intervalMinutes <
                                    PopSettings.maxIntervalMinutes
                                ? () => notifier.setIntervalMinutes(
                                    settings.intervalMinutes + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── 1回の問題数 ──
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
                                ? () =>
                                    notifier.setPopCount(settings.popCount - 1)
                                : null,
                          ),
                          Text('${settings.popCount}'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: settings.popCount < PopSettings.maxPopCount
                                ? () =>
                                    notifier.setPopCount(settings.popCount + 1)
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

  Future<void> _openSelectApps(
    BuildContext context,
    WidgetRef ref,
    DeckPopSettings settings,
    DeckPopSettingsNotifier notifier,
  ) async {
    final result = await Navigator.of(context).push<
        ({Set<String> packageNames, Set<String> urls})>(
      MaterialPageRoute(
        builder: (_) => SelectAppsScreen(
          initialPackageNames: settings.packageNames,
          initialUrls: settings.customUrls,
        ),
      ),
    );
    if (result == null) return;
    await notifier.setPackageNames(result.packageNames);
    await notifier.setCustomUrls(result.urls);
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app});
  final InstalledApp app;

  @override
  Widget build(BuildContext context) {
    final bytes = app.iconBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(bytes, width: 32, height: 32, fit: BoxFit.cover),
      );
    }
    return CircleAvatar(
      radius: 16,
      child: Text(app.label.isNotEmpty ? app.label[0].toUpperCase() : '?'),
    );
  }
}
