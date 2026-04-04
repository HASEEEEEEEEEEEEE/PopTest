import 'package:flutter/material.dart';

/// Stats screen – placeholder with metric tiles.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('統計')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('学習サマリー',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _StatTile(
              label: '学習数',
              value: '—',
              color: colorScheme.primaryContainer,
            ),
            _StatTile(
              label: '正答率',
              value: '—',
              color: colorScheme.secondaryContainer,
            ),
            _StatTile(
              label: '割り込み回数',
              value: '—',
              color: colorScheme.tertiaryContainer,
            ),
            _StatTile(
              label: '学習時間換算量',
              value: '—',
              color: colorScheme.surfaceContainerHighest,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label),
        trailing: Text(value,
            style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
