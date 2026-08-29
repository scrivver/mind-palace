// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';

import '../models/picked_file.dart';

Future<List<PickedFile>?> pickFiles({bool allowMultiple = true}) async {
  final completer = Completer<List<PickedFile>?>();

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
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final result = <PickedFile>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final bytes = await _readFileBytes(file);
      // A plain file selection has no folder context to preserve.
      result.add(
        PickedFile(
          PlatformFile(name: file.name, size: file.size, bytes: bytes),
        ),
      );
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

Future<List<PickedFile>?> pickFolder() async {
  final completer = Completer<List<PickedFile>?>();

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
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final result = <PickedFile>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final bytes = await _readFileBytes(file);
      // dart:html exposes the JS `webkitRelativePath` property under the Dart
      // name `relativePath` (@JSName in html_dart2js.dart). File is a @Native
      // class, so reading `webkitRelativePath` dynamically throws
      // NoSuchMethodError instead of returning the path — do not "fix" this
      // back to the JS spelling.
      //
      // The value is already relative and already includes the selected
      // folder's own name, e.g. `Photos/2026/a.jpg`.
      final rawRelative = file.relativePath;
      final relative = (rawRelative != null && rawRelative.isNotEmpty)
          ? rawRelative
          : null;

      result.add(
        PickedFile(
          PlatformFile(name: file.name, size: file.size, bytes: bytes),
          relativePath: relative,
        ),
      );
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
