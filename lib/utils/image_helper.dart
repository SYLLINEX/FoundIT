import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageHelper {
  /// Normalizes an XFile to ensure it is not a HEIC/HEIF file.
  /// If it is, transcodes it to JPEG using flutter_image_compress.
  /// Otherwise, returns the original XFile.
  static Future<XFile> normalizeImage(XFile file) async {
    final lowerPath = file.path.toLowerCase();
    if (!lowerPath.endsWith('.heic') && !lowerPath.endsWith('.heif')) {
      return file;
    }

    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/${const Uuid().v4()}.jpg';
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path, 
        targetPath,
        format: CompressFormat.jpeg,
        quality: 90,
      );

      if (result != null) {
        return result;
      }
    } catch (e) {
      // Fallback to original if conversion fails
      print('Error converting HEIC to JPEG: $e');
    }

    return file;
  }
}
