import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pop_study/pop_models.dart';
import '../pop_study/pop_metrics.dart';
import '../pop_study/pop_metrics_model.dart';
import '../pop_study/deck_pop_settings.dart';
import '../pop_study/pop_repository.dart';
import '../pop_study/pop_settings.dart';
import '../pop_study/pop_study_active_provider.dart';
import 'selected_deck_provider.dart';

final nowTickerProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final decks = ref.watch(deckRepositoryProvider).values.toList();
    final selectedDeckId = ref.watch(selectedDeckProvider);
    final globalPopSettings = ref.watch(popSettingsProvider);
    final isActive = ref.watch(popStudyActiveProvider);
    final metrics = ref.watch(popMetricsProvider);
    final now = ref.watch(nowTickerProvider).value ?? DateTime.now();
    final selectedDeckIdOrEmpty = selectedDeckId ?? '';
    final hasSelectedDeck = selectedDeckId != null;
    final selectedDeckSettings = !hasSelectedDeck
        ? null
        : ref.watch(deckPopSettingsProvider(selectedDeckIdOrEmpty));
    final useGlobalSettings =
        !hasSelectedDeck || (selectedDeckSettings?.useGlobal ?? true);
    final effectivePopSettings = !hasSelectedDeck
        ? globalPopSettings
        : ref.watch(effectivePopSettingsProvider(selectedDeckIdOrEmpty));

    final selectedDeck = decks.firstWhere(
      (d) => d.deckId == selectedDeckId,
      orElse: () => DeckData(deckId: '', name: '', cards: const []),
    );
    final deckName = selectedDeckId != null && selectedDeck.deckId.isNotEmpty
        ? selectedDeck.name
        : null;

    final hasTargets = effectivePopSettings.services.isNotEmpty ||
        effectivePopSettings.customUrls.isNotEmpty;
    final canStart = selectedDeckId != null && hasTargets;

    // 残り視聴秒数でカウントダウン
    final intervalSeconds = effectivePopSettings.intervalMinutes * 60;
    final remainingSeconds =
        (intervalSeconds - metrics.viewingSecondsForCurrentInterval)
            .clamp(0, intervalSeconds);
    final countdownLabel = metrics.sessionStartedAt == null
        ? '--:--'
        : formatDurationAsMinutesSeconds(
            Duration(seconds: remainingSeconds),
          );
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
                  Text('今日の学習', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _MetricCard(
                    label: 'ポップ表示回数',
                    value: '${metrics.popupShownCount}',
                    icon: Icons.menu_book_outlined,
                    color: colorScheme.primaryContainer,
                  ),
                  _MetricCard(
                    label: '開始回数',
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
                    label: '追跡イベント数',
                    value: '${metrics.trackedEventCount}',
                    icon: Icons.track_changes_outlined,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  _MetricCard(
                    label: '一致イベント数',
                    value: '${metrics.matchedEventCount}',
                    icon: Icons.link_outlined,
                    color: colorScheme.surfaceContainer,
                  ),
                  _MetricCard(
                    label: '対象サービス視聴時間',
                    value: watchedLabel,
                    icon: Icons.timer_outlined,
                    color: colorScheme.surfaceContainerLow,
                  ),
                  const SizedBox(height: 24),
                  Text('ポップ学習', style: Theme.of(context).textTheme.titleMedium),
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
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('対象サービス'),
                          Text(
                            '問題を表示するSNSを選択（複数可）',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: PopService.values
                                .map(
                                  (service) => FilterChip(
                                    label: Text(service.label),
                                    selected: effectivePopSettings.services
                                        .contains(service),
                                    onSelected: !hasSelectedDeck
                                        ? (_) => ref
                                            .read(popSettingsProvider.notifier)
                                            .toggleService(service)
                                        : useGlobalSettings
                                            ? (_) => ref
                                                .read(popSettingsProvider
                                                    .notifier)
                                                .toggleService(service)
                                            : (_) => ref
                                                .read(deckPopSettingsProvider(
                                                        selectedDeckIdOrEmpty)
                                                    .notifier)
                                                .toggleService(service),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          _CustomUrlSection(
                            urls: effectivePopSettings.customUrls,
                            onAdd: (url) {
                              if (!hasSelectedDeck || useGlobalSettings) {
                                ref
                                    .read(popSettingsProvider.notifier)
                                    .addCustomUrl(url);
                                return;
                              }
                              ref
                                  .read(deckPopSettingsProvider(
                                          selectedDeckIdOrEmpty)
                                      .notifier)
                                  .addCustomUrl(url);
                            },
                            onRemove: (url) {
                              if (!hasSelectedDeck || useGlobalSettings) {
                                ref
                                    .read(popSettingsProvider.notifier)
                                    .removeCustomUrl(url);
                                return;
                              }
                              ref
                                  .read(deckPopSettingsProvider(
                                          selectedDeckIdOrEmpty)
                                      .notifier)
                                  .removeCustomUrl(url);
                            },
                          ),
                          if (!hasTargets)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'サービス/URL未指定：ポップ学習を開始できません',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.error,
                                    ),
                              ),
                            ),
                        ],
                      ),
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
                                : 'デッキとサービスを選択してください',
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

class _CustomUrlSection extends StatefulWidget {
  const _CustomUrlSection({
    required this.urls,
    required this.onAdd,
    required this.onRemove,
  });

  final Set<String> urls;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<_CustomUrlSection> createState() => _CustomUrlSectionState();
}

class _CustomUrlSectionState extends State<_CustomUrlSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('対象URL（前方一致）'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '例: youtube.com/shorts',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () {
                final value = _controller.text.trim();
                if (value.isEmpty) return;
                widget.onAdd(value);
                _controller.clear();
              },
              child: const Text('追加'),
            ),
          ],
        ),
        if (widget.urls.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.urls
                .map((url) => InputChip(
                      label: Text(url),
                      onDeleted: () => widget.onRemove(url),
                    ))
                .toList(),
          ),
        ],
      ],
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
