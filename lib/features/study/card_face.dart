import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/media_storage.dart';
import '../pop_study/pop_models.dart';

/// Card face widget supporting text + image + audio for both sides.
///
/// Layout:
/// - Image (if any) expands to fill available height. Text sits below.
/// - When back is revealed, the visible card is split top/bottom.
/// - An optional edit button is shown top-right when [onEdit] is provided.
///
/// Audio behavior:
/// - Front audio auto-plays once per (card, side).
/// - Back audio auto-plays once when the back is first revealed.
/// - A speaker button replays the audio for the visible side.
class CardFace extends ConsumerStatefulWidget {
  const CardFace({
    super.key,
    required this.card,
    required this.showBack,
    this.onEdit,
  });

  final CardModel card;
  final bool showBack;
  final VoidCallback? onEdit;

  @override
  ConsumerState<CardFace> createState() => _CardFaceState();
}

class _CardFaceState extends ConsumerState<CardFace> {
  final _player = AudioPlayer();
  String? _lastPlayedCardId;
  bool _lastShowBack = false;

  @override
  void initState() {
    super.initState();
    _maybeAutoPlay();
  }

  @override
  void didUpdateWidget(CardFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeAutoPlay();
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _maybeAutoPlay() async {
    final cardChanged = _lastPlayedCardId != widget.card.id;
    final sideChanged = _lastShowBack != widget.showBack;
    if (!cardChanged && !sideChanged) return;
    _lastPlayedCardId = widget.card.id;
    _lastShowBack = widget.showBack;
    await _playCurrentSide();
  }

  Future<void> _playCurrentSide() async {
    final media = widget.showBack ? widget.card.backMedia : widget.card.frontMedia;
    final url = media.audioUrl;
    if (url == null || url.isEmpty) return;
    final abs = await ref.read(mediaStorageProvider).resolveAbsolutePath(url);
    if (abs == null) return;
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(abs));
    } catch (_) {/* ignore playback errors */}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Column(
              children: [
                Expanded(
                  child: _Face(
                    card: widget.card,
                    isBack: false,
                    textStyle: theme.textTheme.headlineMedium,
                    onReplay: _playCurrentSide,
                    showReplayButton: !widget.showBack,
                  ),
                ),
                if (widget.showBack) ...[
                  const Divider(height: 24),
                  Expanded(
                    child: _Face(
                      card: widget.card,
                      isBack: true,
                      textStyle: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      onReplay: _playCurrentSide,
                      showReplayButton: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.onEdit != null)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'カードを編集',
              onPressed: widget.onEdit,
            ),
          ),
      ],
    );
  }
}

class _Face extends ConsumerWidget {
  const _Face({
    required this.card,
    required this.isBack,
    required this.textStyle,
    required this.onReplay,
    required this.showReplayButton,
  });

  final CardModel card;
  final bool isBack;
  final TextStyle? textStyle;
  final VoidCallback onReplay;
  final bool showReplayButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = isBack ? card.backMedia : card.frontMedia;
    final text = isBack ? card.back : card.front;
    return Column(
      children: [
        if (media.hasImage)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CardImage(relativePath: media.imageUrl!),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(text, style: textStyle, textAlign: TextAlign.center),
            ),
            if (media.hasAudio && showReplayButton) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.volume_up),
                onPressed: onReplay,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CardImage extends ConsumerWidget {
  const _CardImage({required this.relativePath});
  final String relativePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: ref.read(mediaStorageProvider).resolveAbsolutePath(relativePath),
      builder: (context, snapshot) {
        final abs = snapshot.data;
        if (abs == null) return const SizedBox.shrink();
        return Image.file(File(abs), fit: BoxFit.contain);
      },
    );
  }
}
