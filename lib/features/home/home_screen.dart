import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pop_study/pop_metrics.dart';
import '../pop_study/deck_pop_settings.dart';
import '../pop_study/pop_repository.dart';
import '../pop_study/pop_settings.dart';
import '../pop_study/pop_study_active_provider.dart';
import 'selected_deck_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final decks = ref.watch(deckRepositoryProvider).values.toList();
    final selectedDeckId = ref.watch(selectedDeckProvider);
    final isActive = ref.watch(popStudyActiveProvider);
    final metrics = ref.watch(popMetricsProvider);
    final selectedDeckIdOrEmpty = selectedDeckId ?? '';
    final hasSelectedDeck = selectedDeckId != null;
    final effectivePopSettings = !hasSelectedDeck
        ? ref.watch(popSettingsProvider)
        : ref.watch(effectivePopSettingsProvider(selectedDeckIdOrEmpty));

    final selectedDeck = decks.firstWhere(
      (d) => d.deckId == selectedDeckId,
      orElse: () => DeckData(deckId: '', name: '', cards: const []),
    );
    final deckName = selectedDeckId != null && selectedDeck.deckId.isNotEmpty
        ? selectedDeck.name
        : null;

    final hasTargets = effectivePopSettings.packageNames.isNotEmpty ||
        effectivePopSettings.customUrls.isNotEmpty;
    final canStart = selectedDeckId != null && hasTargets;

    final intervalSeconds = effectivePopSettings.intervalMinutes * 60;
    final remainingSeconds =
        (intervalSeconds - metrics.viewingSecondsForCurrentInterval)
            .clamp(0, intervalSeconds);
    final countdownLabel = metrics.sessionStartedAt == null
        ? '--:--'
        : formatDurationAsMinutesSeconds(Duration(seconds: remainingSeconds));
    final watchedLabel = formatDurationAsMinutesSeconds(
      Duration(seconds: metrics.matchedActiveSeconds),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('ホーム')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isActive)
            _PopStudyStatusBar(
              deckName: deckName,
              questionsPerPopup: effectivePopSettings.popCount,
              nextStudyCountdownLabel: countdownLabel,
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── ポップ学習 ──────────────────────────────
                  Text(
                    'ポップ学習',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'デッキを選択',
                          border: InputBorder.none,
                        ),
                        value: decks.any((d) => d.deckId == selectedDeckId)
                            ? selectedDeckId
                            : null,
                        hint: const Text('デッキを選択してください'),
                        items: decks
                            .map((d) => DropdownMenuItem(
                                  value: d.deckId,
                                  child: Text(d.name),
                                ))
                            .toList(),
                        onChanged: (id) =>
                            ref.read(selectedDeckProvider.notifier).select(id),
                      ),
                    ),
                  ),
                  if (!hasTargets && !isActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            '監視タブでアプリ・URLを設定してください',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Card(
                    color: isActive
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    child: SwitchListTile(
                      title: Text(
                        isActive ? 'ポップ学習を停止' : 'ポップ学習を開始',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: isActive
                                  ? colorScheme.onPrimaryContainer
                                  : null,
                            ),
                      ),
                      subtitle: Text(
                        isActive
                            ? '学習中 — SNS視聴中に問題が表示されます'
                            : canStart
                                ? 'タップして開始'
                                : 'デッキと監視対象を設定してください',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isActive
                                  ? colorScheme.onPrimaryContainer
                                      .withOpacity(0.8)
                                  : null,
                            ),
                      ),
                      value: isActive,
                      onChanged: canStart || isActive
                          ? (v) => ref
                              .read(popStudyActiveProvider.notifier)
                              .setActive(v)
                          : null,
                    ),
                  ),

                  // ── 今日の学習 ──────────────────────────────
                  const SizedBox(height: 24),
                  Text(
                    '今日の学習',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _MetricCard(
                    label: 'ポップ表示回数',
                    value: '${metrics.popupShownCount}',
                    icon: Icons.menu_book_outlined,
                    color: colorScheme.primaryContainer,
                  ),
                  _MetricCard(
                    label: '学習開始回数',
                    value: '${metrics.popupStartCount}',
                    icon: Icons.check_circle_outline,
                    color: colorScheme.secondaryContainer,
                  ),
                  _MetricCard(
                    label: 'スキップ回数',
                    value: '${metrics.popupSnoozeCount}',
                    icon: Icons.notifications_outlined,
                    color: colorScheme.tertiaryContainer,
                  ),
                  _MetricCard(
                    label: '視聴時間',
                    value: watchedLabel,
                    icon: Icons.timer_outlined,
                    color: colorScheme.surfaceContainerLow,
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

class _PopStudyStatusBar extends StatelessWidget {
  const _PopStudyStatusBar({
    required this.deckName,
    required this.questionsPerPopup,
    required this.nextStudyCountdownLabel,
  });

  final String? deckName;
  final int questionsPerPopup;
  final String nextStudyCountdownLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = deckName != null
        ? 'デッキ: $deckName（$questionsPerPopup問）を学習中'
        : 'ポップ学習中（$questionsPerPopup問）';

    return Container(
      width: double.infinity,
      color: colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.auto_stories, size: 16, color: colorScheme.onPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label / 次回まで: $nextStudyCountdownLabel',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
