import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';

Future<List<PlatformFile>?> pickFiles({bool allowMultiple = true}) async {
  final completer = Completer<List<PlatformFile>?>();

  final input = html.FileUploadInputElement()
    ..multiple = allowMultiple
    ..style.display = 'none';

  // Fallback timer in case the browser doesn't fire onChange when the
  // user cancels the dialog.
  final fallback = Timer(const Duration(seconds: 8), () {
    if (!completer.isCompleted) {
      completer.complete(null);
      try {
        input.remove();
      } catch (_) {}
    }
  });

  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      try {
        input.remove();
      } catch (_) {}
      try {
        fallback.cancel();
      } catch (_) {}
      return;
    }

    // We got a selection; cancel the fallback timer immediately so large
    // selections don't get interrupted while we read file bytes.
    try {
      fallback.cancel();
    } catch (_) {}

    final result = <PlatformFile>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i] as html.File;
      final bytes = await _readFileBytes(file);
      result.add(PlatformFile(name: file.name, size: file.size, bytes: bytes));
    }

    if (!completer.isCompleted) completer.complete(result);
    try {
      input.remove();
    } catch (_) {}
    try {
      fallback.cancel();
    } catch (_) {}
  });

  html.document.body!.append(input);
  input.click();

  return completer.future;
}

Future<List<PlatformFile>?> pickFolder() async {
  final completer = Completer<List<PlatformFile>?>();

  final input = html.FileUploadInputElement()
    ..multiple = true
    ..style.display = 'none';

  input.setAttribute('webkitdirectory', '');

  // Fallback timer
  final fallback = Timer(const Duration(seconds: 8), () {
    if (!completer.isCompleted) {
      completer.complete(null);
      try {
        input.remove();
      } catch (_) {}
    }
  });

  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      try {
        input.remove();
      } catch (_) {}
      try {
        fallback.cancel();
      } catch (_) {}
      return;
    }

    // Cancel fallback immediately when a selection is made; reading many
    // file bytes can take longer than the fallback timeout.
    try {
      fallback.cancel();
    } catch (_) {}

    final result = <PlatformFile>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i] as html.File;
      final bytes = await _readFileBytes(file);
      // webkitRelativePath is non-standard and may not exist on all browsers.
      // Access it safely and fall back to null when missing.
      String? relative;
      try {
        final dyn = file as dynamic;
        final val = dyn.webkitRelativePath;
        if (val is String && val.isNotEmpty) relative = val;
      } catch (_) {
        relative = null;
      }

      result.add(PlatformFile(name: file.name, size: file.size, bytes: bytes, path: relative));
    }

    if (!completer.isCompleted) completer.complete(result);
    try {
      input.remove();
    } catch (_) {}
    try {
      fallback.cancel();
    } catch (_) {}
  });

  html.document.body!.append(input);
  input.click();

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
