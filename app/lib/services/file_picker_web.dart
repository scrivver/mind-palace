import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

Future<List<PlatformFile>?> pickFiles({bool allowMultiple = true}) async {
  final completer = Completer<List<PlatformFile>?>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = allowMultiple
    ..style.display = 'none';

  input.onChange.listen((event) async {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      input.remove();
      return;
    }

    final result = <PlatformFile>[];
    for (var i = 0; i < files.length; i++) {
      final file = files.item(i)!;
      final bytes = await _readFileBytes(file);
      result.add(PlatformFile(
        name: file.name,
        size: file.size,
        bytes: bytes,
      ));
    }

    if (!completer.isCompleted) completer.complete(result);
    input.remove();
  });

  web.document.body!.append(input);
  input.click();

  return completer.future;
}

Future<Uint8List> _readFileBytes(web.File file) async {
  final completer = Completer<Uint8List>();
  final reader = web.FileReader();

  reader.onLoadEnd.listen((_) {
    final result = reader.result;
    if (result != null) {
      final arrayBuffer = result as JSArrayBuffer;
      final bytes = arrayBuffer.toDart.asUint8List();
      completer.complete(bytes);
    } else {
      completer.complete(Uint8List(0));
    }
  });

  reader.readAsArrayBuffer(file);
  return completer.future;
}
