import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/router.dart';
import '../pop_study/pop_repository.dart';
import 'deck_import.dart';

class DeckImportScreen extends ConsumerStatefulWidget {
  const DeckImportScreen({super.key});

  @override
  ConsumerState<DeckImportScreen> createState() => _DeckImportScreenState();
}

class _DeckImportScreenState extends ConsumerState<DeckImportScreen> {
  String? _fileName;
  String? _content;
  CardDelimiter _delimiter = CardDelimiter.tab;
  final _deckNameController = TextEditingController();
  bool _importing = false;

  @override
  void dispose() {
    _deckNameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // FileType.any so Google Drive / cloud-provider files show up.
    // Filtering with custom extensions on Android SAF can hide Drive entries.
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes ?? await _readBytesFromPath(file.path);
    if (bytes == null) return;
    final content = _decodeBytes(bytes);
    setState(() {
      _fileName = file.name;
      _content = content;
      _delimiter = detectDelimiter(content);
      if (_deckNameController.text.isEmpty) {
        _deckNameController.text = _stripExtension(file.name);
      }
    });
  }

  Future<List<int>?> _readBytesFromPath(String? path) async {
    if (path == null) return null;
    try {
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Decodes bytes as UTF-8, falling back to Latin-1 if invalid UTF-8 is encountered.
  /// Strips a leading BOM if present.
  String _decodeBytes(List<int> bytes) {
    var data = bytes;
    if (data.length >= 3 &&
        data[0] == 0xEF &&
        data[1] == 0xBB &&
        data[2] == 0xBF) {
      data = data.sublist(3);
    }
    try {
      return utf8.decode(data);
    } catch (_) {
      return latin1.decode(data);
    }
  }

  String _stripExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  Future<void> _runImport(List<ImportedCard> cards) async {
    final name = _deckNameController.text.trim();
    if (name.isEmpty || cards.isEmpty) return;
    setState(() => _importing = true);
    final repo = ref.read(deckRepositoryProvider.notifier);
    final deckId = repo.addDeck(name);
    if (deckId.isEmpty) {
      setState(() => _importing = false);
      return;
    }
    await repo.addCardsBulk(
      deckId,
      cards.map((c) => (front: c.front, back: c.back)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${cards.length}枚のカードをインポートしました')),
    );
    context.go('${AppRoutes.decks}/$deckId');
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    final cards = content == null
        ? <ImportedCard>[]
        : parseImportedCards(content, _delimiter);

    return Scaffold(
      appBar: AppBar(title: const Text('デッキをインポート')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.file_open),
              label: Text(_fileName ?? 'ファイルを選択 (.txt / .csv / .tsv)'),
              onPressed: _importing ? null : _pickFile,
            ),
            const SizedBox(height: 16),
            if (content != null) ...[
              TextField(
                controller: _deckNameController,
                decoration: const InputDecoration(
                  labelText: 'デッキ名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CardDelimiter>(
                value: _delimiter,
                decoration: const InputDecoration(
                  labelText: '区切り文字',
                  border: OutlineInputBorder(),
                ),
                items: CardDelimiter.values
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d.label),
                        ))
                    .toList(),
                onChanged: _importing
                    ? null
                    : (v) {
                        if (v != null) setState(() => _delimiter = v);
                      },
              ),
              const SizedBox(height: 16),
              Text(
                'プレビュー (${cards.length}枚)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      '解析できる行がありません。区切り文字を変えてみてください。',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: cards.take(10).map((c) {
                      return ListTile(
                        dense: true,
                        title: Text(c.front, maxLines: 2),
                        subtitle: Text(c.back, maxLines: 2),
                      );
                    }).toList(),
                  ),
                ),
              if (cards.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '...他 ${cards.length - 10} 枚',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download),
                label: Text(_importing
                    ? 'インポート中...'
                    : '${cards.length}枚をインポート'),
                onPressed: _importing ||
                        cards.isEmpty ||
                        _deckNameController.text.trim().isEmpty
                    ? null
                    : () => _runImport(cards),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
