import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:archive/archive.dart';

final Map<String, JSObject> _directoryHandles = {};
int _handleSequence = 0;

/// Call directly from a user click handler on a supported browser.
Future<String?> chooseDestination() async {
  try {
    final picker = globalContext['showDirectoryPicker'];
    if (picker == null) return null;

    final result = globalContext.callMethod<JSAny?>('showDirectoryPicker'.toJS);

    if (result == null) return null;

    final handle = await (result as JSPromise<JSObject>).toDart;
    final token = 'directory-${++_handleSequence}';

    _directoryHandles[token] = handle;
    return token;
  } catch (error) {
    print('chooseDestination error: $error');
    return null;
  }
}

Future<bool> saveZipAsFolder({
  required String destination,
  required String folderName,
  required Uint8List zipBytes,
}) async {
  final baseHandle = _directoryHandles.remove(destination);
  if (baseHandle == null) return false;

  try {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final folder = await _directoryHandle(baseHandle, _safeSegment(folderName));

    for (final entry in archive.files) {
      if (!entry.isFile) continue;

      final segments = entry.name
          .replaceAll('\\', '/')
          .split('/')
          .where((part) => part.isNotEmpty && part != '.' && part != '..')
          .map(_safeSegment)
          .toList();

      if (segments.isEmpty) continue;

      JSObject current = folder;

      for (final segment in segments.take(segments.length - 1)) {
        current = await _directoryHandle(current, segment);
      }

      final file = await _fileHandle(current, segments.last);
      final writableResult = await _promiseMethod(file, 'createWritable');

      if (writableResult == null) {
        throw StateError('Could not create writable stream.');
      }

      final writable = writableResult as JSObject;
      final content = entry.content;

      final bytes = content is Uint8List
          ? content
          : Uint8List.fromList(List<int>.from(content as Iterable));

      await _promiseMethod(writable, 'write', <JSAny?>[bytes.toJS]);

      await _promiseMethod(writable, 'close');
    }

    return true;
  } catch (error, stackTrace) {
    print('saveZipAsFolder error: $error');
    print(stackTrace);
    return false;
  }
}

JSObject _createOptions() {
  final constructor = globalContext['Object'] as JSFunction;
  final result = constructor.callAsFunction(null);

  if (result == null) {
    throw StateError('Could not create JavaScript options.');
  }

  final options = result as JSObject;
  options.setProperty('create'.toJS, true.toJS);

  return options;
}

Future<JSObject> _directoryHandle(JSObject parent, String name) async {
  final result = await _promiseMethod(parent, 'getDirectoryHandle', <JSAny?>[
    name.toJS,
    _createOptions(),
  ]);

  if (result == null) {
    throw StateError('Could not create directory: $name');
  }

  return result as JSObject;
}

Future<JSObject> _fileHandle(JSObject parent, String name) async {
  final result = await _promiseMethod(parent, 'getFileHandle', <JSAny?>[
    name.toJS,
    _createOptions(),
  ]);

  if (result == null) {
    throw StateError('Could not create file: $name');
  }

  return result as JSObject;
}

Future<JSAny?> _promiseMethod(
  JSObject target,
  String method, [
  List<JSAny?> args = const <JSAny?>[],
]) async {
  final result = target.callMethodVarArgs<JSAny?>(method.toJS, args);

  if (result == null) {
    throw StateError('JavaScript method returned null: $method');
  }

  return (result as JSPromise<JSAny?>).toDart;
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
