// Web-only utilities for expanding dropped directories.
// This file uses dart:html and is only compiled on web.
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Walk a DataTransferItemList and return PlatformFile entries for files.
Future<List<PlatformFile>> expandDropItemsWeb(html.DataTransferItemList items) async {
  final out = <PlatformFile>[];

  final futures = <Future<void>>[];
  // DataTransferItemList.length is a non-null int on web; use its value
  final len = items.length ?? 0;
  for (var i = 0; i < len; i++) {
    final item = items[i]!;
    if (item.kind != 'file') continue;

    final file = item.getAsFile();
    if (file == null) continue;

    final f = file as html.File;
    final reader = html.FileReader();
    final completer = Completer<void>();

    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      Uint8List bytes;
      if (result is ByteBuffer) {
        bytes = Uint8List.view(result);
      } else if (result is List<int>) {
        bytes = Uint8List.fromList(result);
      } else {
        bytes = Uint8List(0);
      }

      final sizeVal = (f.size == null) ? bytes.length : f.size!;
      out.add(PlatformFile(name: f.name, size: sizeVal, bytes: bytes));
      completer.complete();
    });

    reader.readAsArrayBuffer(f);
    futures.add(completer.future);
  }

  await Future.wait(futures);
  return out;
}
