import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Where on a card the media is attached.
enum MediaSide { front, back }

/// What kind of media is being stored.
enum MediaKind { image, audio }

/// Limits enforced when accepting new media. Tuned to support ~10,000 cards
/// per user while staying inside Firebase Storage Spark (5GB free tier).
///
/// Budget math: 10,000 cards × 2 sides × ~150KB average = ~3GB worst case.
/// Most cards will have only one image side or none, so real usage is lower.
class MediaLimits {
  /// Hard ceiling per image after crop/resize.
  static const int maxImageBytes = 200 * 1024; // 200 KB

  /// Maximum size for a single audio file. Encourages short pronunciation
  /// clips rather than long recordings.
  static const int maxAudioBytes = 500 * 1024; // 500 KB

  /// Image resize target (longer edge). 800px is enough for crisp display
  /// at any practical card size while keeping JPEG files small.
  static const int imageMaxEdge = 800;

  /// JPEG quality used when re-encoding picked images.
  /// 70 is the standard sweet spot for photos (visually near-lossless,
  /// ~half the size of quality 90).
  static const int imageQuality = 70;
}

/// Saves and resolves media files in the app's documents directory.
///
/// Stored paths are *relative* to the media root so they survive reinstall
/// and (later) translate naturally to Firebase Storage object keys.
class MediaStorage {
  MediaStorage();

  static const String _rootDir = 'poptest_media';

  Future<Directory> _mediaRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/$_rootDir');
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  String _fileName(MediaSide side, MediaKind kind, String extension) {
    final s = side == MediaSide.front ? 'front' : 'back';
    final k = kind == MediaKind.image ? 'image' : 'audio';
    return '${s}_$k.$extension';
  }

  /// Returns the absolute path on disk for a stored [relativePath].
  /// Returns `null` if the file no longer exists.
  Future<String?> resolveAbsolutePath(String relativePath) async {
    if (relativePath.isEmpty) return null;
    final root = await _mediaRoot();
    final fullPath = '${root.path}/$relativePath';
    if (!await File(fullPath).exists()) return null;
    return fullPath;
  }

  /// Copies [sourceFile] into the deck/card directory and returns the relative
  /// path saved into [CardMedia]. Returns null if the file exceeds limits.
  Future<String?> saveMediaFile({
    required String deckId,
    required String cardId,
    required MediaSide side,
    required MediaKind kind,
    required File sourceFile,
    required String extension,
  }) async {
    final size = await sourceFile.length();
    final limit =
        kind == MediaKind.image ? MediaLimits.maxImageBytes : MediaLimits.maxAudioBytes;
    if (size > limit) return null;

    final root = await _mediaRoot();
    final dir = Directory('${root.path}/$deckId/$cardId');
    if (!await dir.exists()) await dir.create(recursive: true);
    final name = _fileName(side, kind, extension);
    final destPath = '${dir.path}/$name';
    await sourceFile.copy(destPath);
    return '$deckId/$cardId/$name';
  }

  /// Deletes a single media file. Safe to call with null or missing paths.
  Future<void> deleteMedia(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    final abs = await resolveAbsolutePath(relativePath);
    if (abs == null) return;
    try {
      await File(abs).delete();
    } catch (_) {/* swallow */}
  }

  /// Deletes the entire directory for a card (used when card is deleted).
  Future<void> deleteCardDirectory(String deckId, String cardId) async {
    final root = await _mediaRoot();
    final dir = Directory('${root.path}/$deckId/$cardId');
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {/* swallow */}
    }
  }

  /// Deletes everything for a deck (used when deck is deleted).
  Future<void> deleteDeckDirectory(String deckId) async {
    final root = await _mediaRoot();
    final dir = Directory('${root.path}/$deckId');
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {/* swallow */}
    }
  }
}

final mediaStorageProvider = Provider<MediaStorage>((_) => MediaStorage());
