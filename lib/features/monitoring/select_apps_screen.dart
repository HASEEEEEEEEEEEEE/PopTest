import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pop_study/native_pop_monitoring.dart';

typedef _Selection = ({Set<String> packageNames, Set<String> urls});

class SelectAppsScreen extends ConsumerStatefulWidget {
  const SelectAppsScreen({
    super.key,
    required this.initialPackageNames,
    required this.initialUrls,
  });

  final Set<String> initialPackageNames;
  final Set<String> initialUrls;

  @override
  ConsumerState<SelectAppsScreen> createState() => _SelectAppsScreenState();
}

class _SelectAppsScreenState extends ConsumerState<SelectAppsScreen> {
  late final Set<String> _selectedPackages;
  late final Set<String> _selectedUrls;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedPackages = Set.of(widget.initialPackageNames);
    _selectedUrls = Set.of(widget.initialUrls);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _queryLooksLikeUrl =>
      _query.isNotEmpty && _query.contains('.');

  List<InstalledApp> _filtered(List<InstalledApp> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((a) =>
            a.label.toLowerCase().contains(q) ||
            a.packageName.toLowerCase().contains(q))
        .toList();
  }

  int get _totalSelected => _selectedPackages.length + _selectedUrls.length;

  void _save() {
    Navigator.of(context).pop<_Selection>(
      (packageNames: _selectedPackages, urls: _selectedUrls),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('アイテムを選択'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'アプリ名またはURLを入力',
              leading: const Icon(Icons.search),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear(),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('読み込みに失敗しました: $e')),
        data: (apps) {
          final filtered = _filtered(apps);
          return ListView.builder(
            itemCount: filtered.length + (_queryLooksLikeUrl ? 1 : 0),
            itemBuilder: (context, index) {
              // URL suggestion shown at the top when query looks like a URL.
              if (_queryLooksLikeUrl && index == 0) {
                final alreadyAdded = _selectedUrls.contains(_query);
                return ListTile(
                  leading: _FaviconAvatar(domain: _query),
                  title: Text(_query),
                  subtitle: const Text('URLとして監視'),
                  trailing: alreadyAdded
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : OutlinedButton(
                          onPressed: () {
                            setState(() => _selectedUrls.add(_query));
                            _searchController.clear();
                          },
                          child: const Text('追加'),
                        ),
                );
              }
              final appIndex =
                  _queryLooksLikeUrl ? index - 1 : index;
              final app = filtered[appIndex];
              final selected = _selectedPackages.contains(app.packageName);
              return CheckboxListTile(
                secondary: _AppIcon(app: app),
                title: Text(app.label),
                subtitle: Text(
                  app.packageName,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                value: selected,
                onChanged: (_) {
                  setState(() {
                    if (selected) {
                      _selectedPackages.remove(app.packageName);
                    } else {
                      _selectedPackages.add(app.packageName);
                    }
                  });
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _totalSelected > 0 ? _save : null,
            child: Text('選択 ($_totalSelected)'),
          ),
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
      child: Text(
        app.label.isNotEmpty ? app.label[0].toUpperCase() : '?',
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
