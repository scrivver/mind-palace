// Web-only utilities for expanding dropped directories.
// This file uses dart:html and is only compiled on web.
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Walk a DataTransferItemList and return PlatformFile entries for files.
///
/// Behavior:
/// - If the browser exposes FileSystemEntry objects via
///   webkitGetAsEntry/getAsEntry, we traverse them recursively and
///   construct PlatformFile.name as the relative path (folder/sub/file).
/// - Otherwise we fall back to reading File objects via item.getAsFile()
///   and use the file.webkitRelativePath when available to preserve
///   directory structure (Chromium provides this). We avoid aggressive
///   placeholder filtering: only explicit placeholder names/paths like
///   '.inode' or 'x-empty' are dropped.
Future<List<PlatformFile>> expandDropItemsWeb(html.DataTransferItemList items) async {
  final out = <PlatformFile>[];
  final seen = <String>{};

  // Helper: read bytes from a html.File
  Future<Uint8List> _readFileBytes(html.File f) async {
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
    reader.onError.listen((e) => completer.completeError(e));
    reader.readAsArrayBuffer(f);
    return completer.future;
  }

  // Helper: get File object from an entry (entry.file(callback))
  Future<dynamic> _fileFromEntry(dynamic entry) async {
    final c = Completer<dynamic>();
    try {
      entry.file((f) => c.complete(f), (e) => c.completeError(e ?? Exception('entry.file failed')));
    } catch (e) {
      c.completeError(e);
    }
    return c.future;
  }

  // Helper: read all entries from a directory reader (readEntries may need
  // to be called repeatedly until it returns an empty array).
  Future<List<dynamic>> _readAllEntries(dynamic dirReader) async {
    final collected = <dynamic>[];
    while (true) {
      final batch = await (() {
        final c = Completer<List<dynamic>>();
        try {
          dirReader.readEntries((entries) => c.complete(List<dynamic>.from(entries)), (e) => c.completeError(e ?? Exception('readEntries failed')));
        } catch (e) {
          c.completeError(e);
        }
        return c.future;
      })();
      if (batch.isEmpty) break;
      collected.addAll(batch);
    }
    return collected;
  }

  bool _looksLikePlaceholder(String p) {
    // Consider a path/name a placeholder only when it contains explicit
    // placeholder path segments such as '.inode' or 'x-empty'. This avoids
    // false positives for legitimate files that may lack an extension.
    final lower = p.toLowerCase();
    final parts = lower.split('/');
    for (final part in parts) {
      if (part == 'x-empty') return true;
      if (part == '.inode') return true;
      if (part.startsWith('.inode')) return true;
    }
    return false;
  }

  // Recursively walk an entry (FileSystemEntry-like) and add files.
  Future<void> _walkEntry(dynamic entry, String basePath) async {
    try {
      final isFile = (entry.isFile as bool?) ?? false;
      final isDir = (entry.isDirectory as bool?) ?? false;
      if (isFile) {
        final file = await _fileFromEntry(entry);
        if (file == null) return;
        final bytes = await _readFileBytes(file as html.File);
        final rel = basePath + (entry.name as String? ?? (file.name as String? ?? ''));
        if (_looksLikePlaceholder(rel)) return;
        if (seen.add(rel)) {
          final sizeVal = (file.size as int?) ?? bytes.length;
          out.add(PlatformFile(name: rel, size: sizeVal, bytes: bytes, path: rel));
        }
      } else if (isDir) {
        final reader = entry.createReader();
        final children = await _readAllEntries(reader);
        for (final child in children) {
          await _walkEntry(child, basePath + (entry.name as String? ?? '') + '/');
        }
      }
    } catch (_) {
      // ignore individual entry errors
    }
  }

  final tasks = <Future<void>>[];
  final len = items.length ?? 0;
  for (var i = 0; i < len; i++) {
    final item = items[i]!;
    if (item.kind != 'file') continue;

    // Prefer entry traversal when available (webkitGetAsEntry/getAsEntry).
    dynamic entry;
    try {
      entry = (item as dynamic).webkitGetAsEntry?.call();
    } catch (_) {
      entry = null;
    }
    if (entry == null) {
      try {
        entry = (item as dynamic).getAsEntry?.call();
      } catch (_) {
        entry = null;
      }
    }

    if (entry != null) {
      tasks.add(_walkEntry(entry, ''));
    } else {
      // Fallback: read the File directly and use webkitRelativePath when
      // available to preserve folder structure on Chromium.
      tasks.add((() async {
        try {
          final file = item.getAsFile();
          if (file == null) return;
          final f = file as html.File;
          final bytes = await _readFileBytes(f);
          String? rel;
          try {
            final dyn = f as dynamic;
            final v = dyn.webkitRelativePath;
            if (v is String && v.isNotEmpty) rel = v;
          } catch (_) {
            rel = null;
          }
          final name = rel ?? (f.name as String? ?? '');
          if (_looksLikePlaceholder(name)) return;
          if (seen.add(name)) {
            final sizeVal = (f.size as int?) ?? bytes.length;
            out.add(PlatformFile(name: name, size: sizeVal, bytes: bytes, path: rel));
          }
        } catch (_) {
          // ignore
        }
      })());
    }
  }

  await Future.wait(tasks);
  return out;
}
