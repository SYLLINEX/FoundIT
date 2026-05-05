import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── Single image upload (kept for backward compat in claim screens) ─────────
  Future<String> uploadItemImage(File imageFile, String userId) async {
    final compressed = await _compressImage(imageFile);
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(imageFile.path)}';
      final ref = _storage.ref().child('items/$userId/$fileName');
      final uploadTask = await ref.putFile(compressed);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // ── Multi-image upload — compresses & uploads all files in parallel ─────────
  Future<List<String>> uploadItemImages(
      List<File> imageFiles, String userId) async {
    final urls = await Future.wait(
      imageFiles.map((f) => uploadItemImage(f, userId)),
    );
    return urls;
  }

  // ── Compress helper: max 1200px wide, 85% quality → ~100–350 KB ────────────
  Future<File> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final ext = p.extension(file.path).toLowerCase();
      final outPath = p.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed$ext',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 85,
        minWidth: 1200,
        minHeight: 1200,
        keepExif: false,
      );

      // If compression fails for any reason, fall back to the original file
      return result != null ? File(result.path) : file;
    } catch (_) {
      return file;
    }
  }
}
