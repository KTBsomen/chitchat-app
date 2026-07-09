import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:heic_to_png_jpg/heic_to_png_jpg.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:image/image.dart' as img;

class MediaNormalizer {
  static Future<bool> _isHeicFile(File file) async {
    try {
      final path = file.path.toLowerCase();
      if (path.endsWith('.heic') || path.endsWith('.heif')) {
        return true;
      }
      final length = await file.length();
      if (length < 12) return false;

      final raf = await file.open(mode: FileMode.read);
      final header = await raf.read(12);
      await raf.close();

      if (header.length < 12) return false;

      // Check for 'ftyp' box signature at offset 4
      if (header[4] == 0x66 && header[5] == 0x74 && header[6] == 0x79 && header[7] == 0x70) {
        final majorBrand = String.fromCharCodes(header.sublist(8, 12));
        if (majorBrand == 'heic' ||
            majorBrand == 'heix' ||
            majorBrand == 'hevc' ||
            majorBrand == 'hevx' ||
            majorBrand == 'mif1' ||
            majorBrand == 'msf1') {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Converts HEIC/HEIF images to PNG, and MOV videos to MP4.
  /// If the file does not need conversion, it returns the original file.
  static Future<File> normalizeFile(File file) async {
    if (Platform.isIOS) {
      return file;
    }
    final path = file.path;
    final extension = p.extension(path).toLowerCase();
    final isHeic = await _isHeicFile(file);

    if (isHeic) {
      try {
        print('[MediaNormalizer] Converting HEIC image to PNG: $path');
        final bytes = await file.readAsBytes();
        final Uint8List? pngBytes =
            await HeicConverter.convertToPNG(heicData: bytes);
        if (pngBytes != null && pngBytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final fileName =
              '${p.basenameWithoutExtension(path)}_${DateTime.now().millisecondsSinceEpoch}.png';
          final outPath = p.join(tempDir.path, fileName);
          final convertedFile = File(outPath);

          // Write PNG bytes directly (avoiding slow decode/encode on main thread)
          await convertedFile.writeAsBytes(pngBytes);
          print('[MediaNormalizer] HEIC converted and written directly to PNG.');
          return convertedFile;
        }
      } catch (e) {
        print('[MediaNormalizer] Error converting HEIC file: $e');
      }
    } else if (extension == '.mov') {
      try {
        print('[MediaNormalizer] Converting MOV video to MP4: $path');
        final tempDir = await getTemporaryDirectory();
        final fileName =
            '${p.basenameWithoutExtension(path)}_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final outPath = p.join(tempDir.path, fileName);

        final editor = VideoEditorBuilder(videoPath: path);
        final resultPath = await editor.export(outputPath: outPath);
        if (resultPath != null && resultPath.isNotEmpty) {
          final convertedFile = File(resultPath);
          if (await convertedFile.exists()) {
            print(
                '[MediaNormalizer] Successfully converted MOV to MP4: $resultPath');
            return convertedFile;
          }
        }
      } catch (e) {
        print('[MediaNormalizer] Error converting MOV file: $e');
      }
    }

    return file;
  }

  /// Batch normalizes a list of files sequentially.
  static Future<List<File>> normalizeFiles(List<File> files) async {
    final normalized = <File>[];
    for (final file in files) {
      normalized.add(await normalizeFile(file));
    }
    return normalized;
  }
}
