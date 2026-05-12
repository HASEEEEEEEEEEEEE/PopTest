import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/media_storage.dart';
import '../pop_study/pop_models.dart';
import '../pop_study/pop_repository.dart';

/// Full-screen editor for a single card. Supports text + image + audio
/// on both front and back.
class CardEditorScreen extends ConsumerStatefulWidget {
  const CardEditorScreen({
    super.key,
    required this.deckId,
    this.cardId,
  });

  final String deckId;
  final String? cardId;

  @override
  ConsumerState<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends ConsumerState<CardEditorScreen> {
  late final TextEditingController _frontController;
  late final TextEditingController _backController;
  late CardMedia _frontMedia;
  late CardMedia _backMedia;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final card = _existingCard();
    _frontController = TextEditingController(text: card?.front ?? '');
    _backController = TextEditingController(text: card?.back ?? '');
    _frontMedia = card?.frontMedia ?? const CardMedia();
    _backMedia = card?.backMedia ?? const CardMedia();
  }

  CardModel? _existingCard() {
    if (widget.cardId == null) return null;
    final deck = ref.read(deckRepositoryProvider)[widget.deckId];
    if (deck == null) return null;
    return deck.cards.firstWhere(
      (c) => c.id == widget.cardId,
      orElse: () => const CardModel(
          id: '', front: '', back: '', state: CardState.newCard),
    );
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final front = _frontController.text.trim();
    final back = _backController.text.trim();
    if (front.isEmpty || back.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('表面と裏面の両方を入力してください')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(deckRepositoryProvider.notifier);
    if (widget.cardId == null) {
      await repo.addCardWithMedia(
        deckId: widget.deckId,
        front: front,
        back: back,
        frontMedia: _frontMedia,
        backMedia: _backMedia,
      );
    } else {
      await repo.updateCardWithMedia(
        deckId: widget.deckId,
        cardId: widget.cardId!,
        front: front,
        back: back,
        frontMedia: _frontMedia,
        backMedia: _backMedia,
      );
    }
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardId == null ? 'カード追加' : 'カード編集'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SideSection(
            label: '表面',
            textController: _frontController,
            media: _frontMedia,
            onMediaChanged: (m) => setState(() => _frontMedia = m),
            deckId: widget.deckId,
            cardId: widget.cardId ?? _draftCardId,
            side: MediaSide.front,
          ),
          const SizedBox(height: 24),
          _SideSection(
            label: '裏面',
            textController: _backController,
            media: _backMedia,
            onMediaChanged: (m) => setState(() => _backMedia = m),
            deckId: widget.deckId,
            cardId: widget.cardId ?? _draftCardId,
            side: MediaSide.back,
          ),
        ],
      ),
    );
  }

  /// Stable ID used to store media while creating a new card. Replaced with
  /// the real card ID on save (media files get moved by the repository).
  late final String _draftCardId =
      'draft-${DateTime.now().millisecondsSinceEpoch}';
}

class _SideSection extends ConsumerWidget {
  const _SideSection({
    required this.label,
    required this.textController,
    required this.media,
    required this.onMediaChanged,
    required this.deckId,
    required this.cardId,
    required this.side,
  });

  final String label;
  final TextEditingController textController;
  final CardMedia media;
  final ValueChanged<CardMedia> onMediaChanged;
  final String deckId;
  final String cardId;
  final MediaSide side;

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final scheme = Theme.of(context).colorScheme;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    // Let the user crop / rotate. Output is constrained so saved files
    // stay under MediaLimits.maxImageBytes.
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: MediaLimits.imageQuality,
      maxWidth: MediaLimits.imageMaxEdge,
      maxHeight: MediaLimits.imageMaxEdge,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '画像をトリミング',
          toolbarColor: scheme.primary,
          toolbarWidgetColor: scheme.onPrimary,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: scheme.primary,
          lockAspectRatio: false,
          hideBottomControls: false,
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(title: '画像をトリミング'),
      ],
    );
    if (cropped == null) return;
    final storage = ref.read(mediaStorageProvider);
    final relativePath = await storage.saveMediaFile(
      deckId: deckId,
      cardId: cardId,
      side: side,
      kind: MediaKind.image,
      sourceFile: File(cropped.path),
      extension: 'jpg',
    );
    if (relativePath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '画像が大きすぎます (上限 ${MediaLimits.maxImageBytes ~/ 1024} KB)')),
        );
      }
      return;
    }
    await storage.deleteMedia(media.imageUrl);
    onMediaChanged(media.copyWith(imageUrl: relativePath));
  }

  Future<void> _pickAudio(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final path = file.path;
    if (path == null) return;
    final ext = (file.extension ?? 'm4a').toLowerCase();
    final storage = ref.read(mediaStorageProvider);
    final relativePath = await storage.saveMediaFile(
      deckId: deckId,
      cardId: cardId,
      side: side,
      kind: MediaKind.audio,
      sourceFile: File(path),
      extension: ext,
    );
    if (relativePath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '音声ファイルが大きすぎます (上限 ${MediaLimits.maxAudioBytes ~/ 1024} KB)')),
        );
      }
      return;
    }
    await storage.deleteMedia(media.audioUrl);
    onMediaChanged(media.copyWith(audioUrl: relativePath));
  }

  Future<void> _removeImage(WidgetRef ref) async {
    await ref.read(mediaStorageProvider).deleteMedia(media.imageUrl);
    onMediaChanged(media.copyWith(clearImage: true));
  }

  Future<void> _removeAudio(WidgetRef ref) async {
    await ref.read(mediaStorageProvider).deleteMedia(media.audioUrl);
    onMediaChanged(media.copyWith(clearAudio: true));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: textController,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: 'テキスト',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _ImagePreview(
              relativePath: media.imageUrl,
              onPick: () => _pickImage(context, ref),
              onRemove: () => _removeImage(ref),
            ),
            const SizedBox(height: 12),
            _AudioPreview(
              relativePath: media.audioUrl,
              onPick: () => _pickAudio(context, ref),
              onRemove: () => _removeAudio(ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends ConsumerWidget {
  const _ImagePreview({
    required this.relativePath,
    required this.onPick,
    required this.onRemove,
  });

  final String? relativePath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (relativePath == null || relativePath!.isEmpty) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.image_outlined),
        label: const Text('画像を追加'),
        onPressed: onPick,
      );
    }
    final storage = ref.read(mediaStorageProvider);
    return FutureBuilder<String?>(
      future: storage.resolveAbsolutePath(relativePath!),
      builder: (context, snapshot) {
        final abs = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: abs == null
                  ? const SizedBox.shrink()
                  : Image.file(File(abs), fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('差し替え'),
                    onPressed: onPick,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AudioPreview extends ConsumerStatefulWidget {
  const _AudioPreview({
    required this.relativePath,
    required this.onPick,
    required this.onRemove,
  });

  final String? relativePath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  ConsumerState<_AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends ConsumerState<_AudioPreview> {
  final _player = AudioPlayer();
  bool _playing = false;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (widget.relativePath == null) return;
    if (_playing) {
      await _player.stop();
      return;
    }
    final abs = await ref
        .read(mediaStorageProvider)
        .resolveAbsolutePath(widget.relativePath!);
    if (abs == null) return;
    await _player.play(DeviceFileSource(abs));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.relativePath == null || widget.relativePath!.isEmpty) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.audiotrack_outlined),
        label: const Text('音声を追加'),
        onPressed: widget.onPick,
      );
    }
    return Row(
      children: [
        IconButton.filledTonal(
          icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
          onPressed: _togglePlay,
        ),
        const SizedBox(width: 8),
        const Expanded(child: Text('音声が設定されています')),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: widget.onPick,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: widget.onRemove,
        ),
      ],
    );
  }
}
