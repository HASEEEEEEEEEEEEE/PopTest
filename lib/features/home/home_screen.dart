import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pop_study/pop_models.dart';
import '../pop_study/deck_pop_settings.dart';
import '../pop_study/pop_repository.dart';
import '../pop_study/pop_settings.dart';
import '../pop_study/pop_study_active_provider.dart';
import 'selected_deck_provider.dart';

/// Home / Dashboard screen.
///
/// Displays today's study metrics, a deck selector, service selection chips,
/// and a pop-study toggle with a live status bar.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final decks = ref.watch(deckRepositoryProvider).values.toList();
    final selectedDeckId = ref.watch(selectedDeckProvider);
    final globalPopSettings = ref.watch(popSettingsProvider);
    final isActive = ref.watch(popStudyActiveProvider);
    final selectedDeckSettings = selectedDeckId == null
        ? null
        : ref.watch(deckPopSettingsProvider(selectedDeckId!));
    final effectivePopSettings = selectedDeckId == null
        ? globalPopSettings
        : ref.watch(effectivePopSettingsProvider(selectedDeckId!));

    final selectedDeck = decks.firstWhere(
      (d) => d.deckId == selectedDeckId,
      orElse: () => DeckData(deckId: '', name: '', cards: const []),
    );
    final deckName =
        selectedDeckId != null && selectedDeck.deckId.isNotEmpty
            ? selectedDeck.name
            : null;

    final canStart =
        selectedDeckId != null && effectivePopSettings.services.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('ホーム')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status bar (visible only while pop-study is active) ────────
          if (isActive)
            _PopStudyStatusBar(
              deckName: deckName,
              questionsPerPopup: effectivePopSettings.popCount,
            ),

          // ── Main content ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今日の学習',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _MetricCard(
                    label: '今日の学習数',
                    value: '—',
                    icon: Icons.menu_book_outlined,
                    color: colorScheme.primaryContainer,
                  ),
                  _MetricCard(
                    label: '正答率',
                    value: '—',
                    icon: Icons.check_circle_outline,
                    color: colorScheme.secondaryContainer,
                  ),
                  _MetricCard(
                    label: '割り込み回数',
                    value: '—',
                    icon: Icons.notifications_outlined,
                    color: colorScheme.tertiaryContainer,
                  ),

                  // ── Pop study settings ─────────────────────────────────
                  const SizedBox(height: 24),
                  Text('ポップ学習',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),

                  // Deck selector
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

                  // Service selection
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
                                      onSelected: selectedDeckId == null
                                          ? (_) => ref
                                              .read(popSettingsProvider.notifier)
                                              .toggleService(service)
                                          : selectedDeckSettings?.useGlobal ==
                                                  true
                                              ? (_) => ref
                                                  .read(popSettingsProvider
                                                      .notifier)
                                                  .toggleService(service)
                                          : (_) => ref
                                              .read(deckPopSettingsProvider(
                                                      selectedDeckId!)
                                                 .notifier)
                                             .toggleService(service),
                                   ),
                                 )
                                 .toList(),
                           ),
                           if (effectivePopSettings.services.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'サービス未選択：ポップ学習を開始できません',
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

                  // Pop-study toggle
                  Card(
                    color: isActive
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    child: SwitchListTile(
                      title: Text(
                        isActive ? 'ポップ学習を停止' : 'ポップ学習を開始',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
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

/// A prominent banner shown at the top of the home screen while pop-study
/// monitoring is active.
class _PopStudyStatusBar extends StatelessWidget {
  const _PopStudyStatusBar({
    required this.deckName,
    required this.questionsPerPopup,
  });

  final String? deckName;
  final int questionsPerPopup;

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
          Icon(Icons.auto_stories,
              size: 16, color: colorScheme.onPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
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
        trailing: Text(value,
            style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
