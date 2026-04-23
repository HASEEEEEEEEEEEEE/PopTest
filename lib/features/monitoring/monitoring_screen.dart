import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pop_study/native_pop_monitoring.dart';
import '../pop_study/pop_settings.dart';
import 'select_apps_screen.dart';

class MonitoringScreen extends ConsumerWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(popSettingsProvider);
    final appsAsync = ref.watch(installedAppsProvider);

    // Build lookup map: packageName → InstalledApp (for label/icon).
    final appsByPackage = appsAsync.valueOrNull != null
        ? {for (final a in appsAsync.value!) a.packageName: a}
        : <String, InstalledApp>{};

    final packages = settings.packageNames.toList();
    final urls = settings.customUrls.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('監視')),
      body: ListView(
        children: [
          _SectionHeader(title: 'アプリ', count: packages.length),
          if (packages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'アプリが選択されていません',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ...packages.map((pkg) {
            final app = appsByPackage[pkg];
            return ListTile(
              leading: app != null
                  ? _AppIcon(app: app)
                  : const CircleAvatar(child: Icon(Icons.apps)),
              title: Text(app?.label ?? pkg),
              subtitle: app != null
                  ? Text(pkg,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis)
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '削除',
                onPressed: () => ref
                    .read(popSettingsProvider.notifier)
                    .removePackage(pkg),
              ),
            );
          }),
          const Divider(height: 1),
          _SectionHeader(title: 'ウェブサイト', count: urls.length),
          if (urls.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'URLが追加されていません',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ...urls.map((url) => ListTile(
                leading: _FaviconAvatar(domain: url),
                title: Text(url, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '削除',
                  onPressed: () => ref
                      .read(popSettingsProvider.notifier)
                      .removeCustomUrl(url),
                ),
              )),
          const SizedBox(height: 88),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSelectApps(context, ref, settings.packageNames,
            settings.customUrls),
        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
    );
  }

  Future<void> _openSelectApps(
    BuildContext context,
    WidgetRef ref,
    Set<String> currentPackages,
    Set<String> currentUrls,
  ) async {
    final result = await Navigator.of(context).push<
        ({Set<String> packageNames, Set<String> urls})>(
      MaterialPageRoute(
        builder: (_) => SelectAppsScreen(
          initialPackageNames: currentPackages,
          initialUrls: currentUrls,
        ),
      ),
    );
    if (result == null) return;
    ref
        .read(popSettingsProvider.notifier)
        .setPackageNames(result.packageNames);
    ref
        .read(popSettingsProvider.notifier)
        .setCustomUrls(result.urls);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        '$title ($count)',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _FaviconAvatar extends StatelessWidget {
  const _FaviconAvatar({required this.domain});
  final String domain;

  @override
  Widget build(BuildContext context) {
    final host = domain.contains('://') ? domain : 'https://$domain';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        'https://www.google.com/s2/favicons?domain_url=$host&sz=64',
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const CircleAvatar(
          child: Icon(Icons.language),
        ),
      ),
    );
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
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover),
      );
    }
    return CircleAvatar(
      child:
          Text(app.label.isNotEmpty ? app.label[0].toUpperCase() : '?'),
    );
  }
}
