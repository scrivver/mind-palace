import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

/// Entries and files captured synchronously from a drop event before the
/// browser invalidates the DataTransfer object.
class CapturedDrop {
  final List<dynamic> entries;
  final List<dynamic> files;
  CapturedDrop(this.entries, this.files);
}

/// Synchronously capture FileSystemEntry objects and File fallbacks from a
/// DataTransferItemList. Must be called inside the drop event handler (sync
/// context) before any await — Firefox invalidates DataTransfer objects once
/// the event handler yields to the microtask queue.
///
/// Casts to package:web's DataTransferItem to call webkitGetAsEntry() (which
/// is the cross-browser name for both Chrome and Firefox per the spec).
CapturedDrop captureDropEntries(dynamic items) {
  final entries = <dynamic>[];
  final files = <dynamic>[];
  final list = items as web.DataTransferItemList;
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (item.kind != 'file') continue;

    final entry = item.webkitGetAsEntry();
    if (entry != null) {
      entries.add(entry);
    } else {
      final f = item.getAsFile();
      if (f != null) files.add(f);
    }
  }
  return CapturedDrop(entries, files);
}

/// Walk pre-captured FileSystemEntry objects and File fallbacks, returning
/// PlatformFile entries. This is the async counterpart to [captureDropEntries].
Future<List<PlatformFile>> expandCapturedDrop(CapturedDrop captured) async {
  final out = <PlatformFile>[];
  final seen = <String>{};

  Future<Uint8List> _readFileBytes(web.File f) async {
    final jsArrayBuffer = await f.arrayBuffer().toDart;
    final byteBuffer = jsArrayBuffer.toDart;
    return Uint8List.view(byteBuffer);
  }

  Future<web.File> _fileFromEntry(web.FileSystemFileEntry entry) async {
    final c = Completer<web.File>();
    entry.file(
      ((JSAny? file) => c.complete(file as web.File)).toJS,
      ((JSAny? err) => c.completeError(err ?? 'file() failed')).toJS,
    );
    return c.future;
  }

  Future<List<web.FileSystemEntry>> _readOneBatch(
      web.FileSystemDirectoryReader reader) async {
    final c = Completer<List<web.FileSystemEntry>>();
    reader.readEntries(
      ((JSAny? entries) {
        final arr = entries as JSArray?;
        if (arr == null || arr.length == 0) {
          c.complete([]);
        } else {
          c.complete(arr.toDart.cast<web.FileSystemEntry>());
        }
      }).toJS,
      ((JSAny? err) => c.completeError(err ?? 'readEntries() failed')).toJS,
    );
    return c.future;
  }

  Future<List<web.FileSystemEntry>> _readAllEntries(
      web.FileSystemDirectoryReader reader) async {
    final collected = <web.FileSystemEntry>[];
    while (true) {
      final batch = await _readOneBatch(reader);
      if (batch.isEmpty) break;
      collected.addAll(batch);
    }
    return collected;
  }

  bool _looksLikePlaceholder(String p) {
    final lower = p.toLowerCase();
    final parts = lower.split('/');
    for (final part in parts) {
      if (part == 'x-empty') return true;
      if (part == '.inode') return true;
      if (part.startsWith('.inode')) return true;
    }
    return false;
  }

  Future<void> _walkEntry(dynamic entry, String basePath) async {
    try {
      final e = entry as web.FileSystemEntry;
      if (e.isFile) {
        final file = await _fileFromEntry(e as web.FileSystemFileEntry);
        final bytes = await _readFileBytes(file);
        final rel = '$basePath${e.name}';
        if (_looksLikePlaceholder(rel)) return;
        if (seen.add(rel)) {
          out.add(PlatformFile(
              name: rel, size: file.size, bytes: bytes, path: rel));
        }
      } else if (e.isDirectory) {
        final dir = e as web.FileSystemDirectoryEntry;
        final reader = dir.createReader();
        final children = await _readAllEntries(reader);
        for (final child in children) {
          await _walkEntry(child, '$basePath${e.name}/');
        }
      }
    } catch (_) {}
  }

  final tasks = <Future<void>>[];

  for (final entry in captured.entries) {
    tasks.add(_walkEntry(entry, ''));
  }

  for (final f in captured.files) {
    tasks.add((() async {
      try {
        final file = f as web.File;
        final bytes = await _readFileBytes(file);
        final name = file.name;
        if (_looksLikePlaceholder(name)) return;
        if (seen.add(name)) {
          out.add(PlatformFile(
              name: name, size: file.size, bytes: bytes, path: null));
        }
      } catch (_) {}
    })());
  }

  await Future.wait(tasks);
  return out;
}

/// Walk a DataTransferItemList and return PlatformFile entries for files.
///
/// Convenience wrapper that calls captureDropEntries then expandCapturedDrop.
Future<List<PlatformFile>> expandDropItemsWeb(dynamic items) async {
  final captured = captureDropEntries(items);
  return expandCapturedDrop(captured);
}
