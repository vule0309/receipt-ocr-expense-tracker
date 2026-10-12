import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class ThumbnailService {
  static final ThumbnailService instance = ThumbnailService._();
  ThumbnailService._();

  /// Saves receipt image and generates a thumbnail in application documents directory
  Future<({String imagePath, String thumbnailPath})> processAndCacheReceipt(
    File sourceImage,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(appDir.path, 'receipts'));
    final thumbsDir = Directory(p.join(appDir.path, 'thumbnails'));

    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    if (!await thumbsDir.exists()) {
      await thumbsDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final imageDestination = p.join(receiptsDir.path, 'receipt_$timestamp.jpg');
    final thumbDestination = p.join(thumbsDir.path, 'thumb_$timestamp.jpg');

    // Copy full image
    final savedFile = await sourceImage.copy(imageDestination);

    try {
      // Decode image and resize thumbnail
      final bytes = await savedFile.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded != null) {
        // Resize to max width 300 while maintaining aspect ratio
        final thumbnail = img.copyResize(decoded, width: 300);
        final thumbBytes = img.encodeJpg(thumbnail, quality: 80);
        final thumbFile = File(thumbDestination);
        await thumbFile.writeAsBytes(thumbBytes);

        return (imagePath: savedFile.path, thumbnailPath: thumbFile.path);
      }
    } catch (e) {
      // Fallback if image decode fails
    }

    return (imagePath: savedFile.path, thumbnailPath: savedFile.path);
  }

  /// Deletes associated images from disk when transaction is removed
  Future<void> deleteCachedFiles({String? imagePath, String? thumbnailPath}) async {
    try {
      if (imagePath != null && imagePath.isNotEmpty) {
        final f = File(imagePath);
        if (await f.exists()) await f.delete();
      }
      if (thumbnailPath != null && thumbnailPath.isNotEmpty && thumbnailPath != imagePath) {
        final f = File(thumbnailPath);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
  }
}

