import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';

Future<List<PlatformFile>?> pickFiles({bool allowMultiple = true}) async {
  final completer = Completer<List<PlatformFile>?>();

  final input = html.FileUploadInputElement()
    ..multiple = allowMultiple
    ..style.display = 'none';

  Timer? safetyTimer;

  void cleanup() {
    safetyTimer?.cancel();
    try {
      input.remove();
    } catch (_) {}
  }

  input.onChange.listen((_) async {
    final files = input.files;
    cleanup();
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final result = <PlatformFile>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i] as html.File;
      final bytes = await _readFileBytes(file);
      result.add(PlatformFile(name: file.name, size: file.size, bytes: bytes));
    }

    if (!completer.isCompleted) completer.complete(result);
  });

  html.document.body!.append(input);
  input.click();

  // Safety net: if onChange never fires (e.g. dialog dismissed without
  // selection in an edge-case browser), eventually clean up rather than
  // leaking the DOM element forever.
  safetyTimer = Timer(const Duration(minutes: 30), () {
    if (!completer.isCompleted) {
      completer.complete(null);
      cleanup();
    }
  });

  return completer.future;
}

Future<List<PlatformFile>?> pickFolder() async {
  final completer = Completer<List<PlatformFile>?>();

  final input = html.FileUploadInputElement()
    ..multiple = true
    ..style.display = 'none';

  input.setAttribute('webkitdirectory', '');

  Timer? safetyTimer;

  void cleanup() {
    safetyTimer?.cancel();
    try {
      input.remove();
    } catch (_) {}
  }

  input.onChange.listen((_) async {
    final files = input.files;
    cleanup();
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final result = <PlatformFile>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i] as html.File;
      final bytes = await _readFileBytes(file);
      String? relative;
      try {
        final dyn = file as dynamic;
        final val = dyn.webkitRelativePath;
        if (val is String && val.isNotEmpty) relative = val;
      } catch (_) {
        relative = null;
      }

      result.add(PlatformFile(
          name: file.name, size: file.size, bytes: bytes, path: relative));
    }

    if (!completer.isCompleted) completer.complete(result);
  });

  html.document.body!.append(input);
  input.click();

  safetyTimer = Timer(const Duration(minutes: 30), () {
    if (!completer.isCompleted) {
      completer.complete(null);
      cleanup();
    }
  });

  return completer.future;
}

Future<Uint8List> _readFileBytes(html.File file) async {
  final completer = Completer<Uint8List>();
  final reader = html.FileReader();

  reader.onLoadEnd.listen((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
    } else if (result is List<int>) {
      completer.complete(Uint8List.fromList(result));
    } else {
      completer.complete(Uint8List(0));
    }
  });

  reader.readAsArrayBuffer(file);
  return completer.future;
}
