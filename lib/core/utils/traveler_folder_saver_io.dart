import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

Future<String?> chooseDestination() =>
    FilePicker.getDirectoryPath(dialogTitle: 'اختيار مكان حفظ مجلد المسافر');

Future<bool> saveZipAsFolder({
  required String destination,
  required String folderName,
  required Uint8List zipBytes,
}) async {
  final decoded = ZipDecoder().decodeBytes(zipBytes, verify: true);
  final safeFolderName = _safeSegment(folderName);
  final root = Directory(p.join(destination, safeFolderName));
  await root.create(recursive: true);

  for (final entry in decoded.files) {
    if (!entry.isFile) continue;
    final segments = p
        .split(entry.name.replaceAll('\\', '/'))
        .where(
          (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
        )
        .map(_safeSegment)
        .toList();
    if (segments.isEmpty) continue;
    final outputPath = p.joinAll(<String>[root.path, ...segments]);
    final output = File(outputPath);
    await output.parent.create(recursive: true);
    final content = entry.content;
    if (content is List<int>) {
      await output.writeAsBytes(content, flush: true);
    } else {
      await output.writeAsBytes(
        List<int>.from(content as Iterable),
        flush: true,
      );
    }
  }
  return true;
}

String _safeSegment(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();
  return cleaned.isEmpty ? 'ملف' : cleaned;
}
