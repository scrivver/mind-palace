// Web-only utilities for expanding dropped directories.
// This file uses dart:html and is only compiled on web.
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Walk a DataTransferItemList and return PlatformFile entries for files.
Future<List<PlatformFile>> expandDropItemsWeb(html.DataTransferItemList items) async {
  final out = <PlatformFile>[];
  // Helper: convert a FileSystemFileEntry/File to PlatformFile
  Future<void> _addFileFromEntry(dynamic fileEntry, String relativePath) async {
    try {
      // If the relative path contains a known placeholder segment like
      // '.inode' or the entry name is the known placeholder 'x-empty',
      // skip it. Some file managers (notably on Linux) encode folder
      // placeholders into the dropped entries (e.g. '.inode/x-empty').
      if (relativePath.contains('.inode') || relativePath.endsWith('/x-empty') || relativePath.endsWith('x-empty')) return;

      // fileEntry.file is callback-based: fileEntry.file(function(file) { ... })
      final file = await (() {
        final c = Completer<dynamic>();
        try {
          fileEntry.file((f) {
            c.complete(f);
          }, (e) {
            c.completeError(e ?? Exception('Failed to read entry.file'));
          });
        } catch (e) {
          c.completeError(e);
        }
        return c.future;
      })();

      final reader = html.FileReader();
      final bytes = await (() {
        final c = Completer<Uint8List>();
        reader.onLoadEnd.listen((_) {
          final result = reader.result;
          if (result is ByteBuffer) {
            c.complete(Uint8List.view(result));
          } else if (result is List<int>) {
            c.complete(Uint8List.fromList(result));
          } else {
            c.complete(Uint8List(0));
          }
        });
        reader.onError.listen((e) => c.completeError(e));
        try {
          reader.readAsArrayBuffer(file as html.File);
        } catch (e) {
          c.completeError(e);
        }
        return c.future;
      })();

      final name = (file as dynamic).name as String? ?? relativePath.split('/').last;
      final sizeVal = (file as dynamic).size as int? ?? bytes.length;
      // Extra safety: skip known placeholder paths/names immediately.
      if (relativePath.contains('.inode') || relativePath.contains('x-empty') || name == 'x-empty' || name.startsWith('.inode')) return;
      // Skip directory-placeholder heuristics: like Firefox sometimes emits
      // a 0-byte empty-type file representing the folder itself.
      // Heuristic to detect directory-placeholder files produced by some
      // file managers/browsers when a folder is dropped. Common signals:
      // - size == 0
      // - empty or 'empty' containing MIME type (e.g. 'application/x-empty')
      // - a name that looks like a placeholder (e.g. startsWith('.inode'))
      // - no file extension
      final typeVal = (file as dynamic).type as String?;
      // Treat as directory-placeholder only for explicit placeholder
      // filenames/paths (e.g. '.inode/*', 'x-empty'). Avoid treating files
      // with no extension as placeholders because many valid files lack
      // extensions (especially on Linux/macOS).
      final looksLikeDirectory = (sizeVal == 0 &&
          ((typeVal == null || typeVal.isEmpty) || typeVal.contains('empty')) &&
          (name.startsWith('.inode') || name == 'x-empty' || relativePath.contains('.inode')));
      if (!looksLikeDirectory) {
        out.add(PlatformFile(name: name, size: sizeVal, bytes: bytes, path: relativePath));
      }
    } catch (_) {
      // Ignore individual failures and continue.
    }
  }

  // Helper: read all entries from a directory reader (readEntries may need
  // to be called repeatedly until it returns an empty array).
  Future<List<dynamic>> _readAllEntries(dynamic dirReader) async {
    final collected = <dynamic>[];
    while (true) {
      final batch = await (() {
        final c = Completer<List<dynamic>>();
        try {
          dirReader.readEntries((entries) {
            c.complete(List<dynamic>.from(entries));
          }, (e) {
            c.completeError(e ?? Exception('readEntries failed'));
          });
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

  // Walk a FileSystemEntry (file or directory) recursively.
  Future<void> _walkEntry(dynamic entry, String basePath) async {
    try {
      final isFile = entry.isFile as bool? ?? false;
      final isDir = entry.isDirectory as bool? ?? false;
      if (isFile) {
        await _addFileFromEntry(entry, basePath + (entry.name as String? ?? ''));
      } else if (isDir) {
        final reader = entry.createReader();
        final children = await _readAllEntries(reader);
        for (final child in children) {
          await _walkEntry(child, basePath + (entry.name as String? ?? '') + '/');
        }
      }
    } catch (_) {
      // Ignore and continue
    }
  }

  final len = items.length ?? 0;
  final tasks = <Future<void>>[];
  for (var i = 0; i < len; i++) {
    final item = items[i]!;
    if (item.kind != 'file') continue;

    // Try to access directory/file entry APIs (webkitGetAsEntry / getAsEntry)
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
      // We have an entry we can traverse. Walk it and collect files with
      // relative paths.
      tasks.add(_walkEntry(entry, ''));
    } else {
      // Fallback: read file directly from the DataTransferItem
      try {
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
          final typeVal = (f.type as String?);
          // Check webkitRelativePath when present (some browsers supply it
          // for dropped directory contents). If it contains '.inode' or
          // the file looks like a placeholder entry, skip it.
          String? rel;
          try {
            final dyn = f as dynamic;
            final v = dyn.webkitRelativePath;
            if (v is String && v.isNotEmpty) rel = v;
          } catch (_) {
            rel = null;
          }
          // Skip if any path/name indicates the known placeholder pattern.
          if ((rel != null && (rel.contains('.inode') || rel.contains('x-empty'))) || f.name == 'x-empty' || f.name.startsWith('.inode')) {
            completer.complete();
            return;
          }

          // Treat as directory-placeholder only for explicit placeholder
          // filenames/paths; do not treat files without an extension as
          // placeholders.
          final looksLikeDirectory = (sizeVal == 0 &&
              ((typeVal == null || typeVal.isEmpty) || typeVal.contains('empty')) &&
              ((f.name.startsWith('.inode') || f.name == 'x-empty') || (rel != null && rel.contains('.inode'))));
          if (!looksLikeDirectory) {
            // Prefer to include the relative path when available
            final path = rel ?? null;
            out.add(PlatformFile(name: f.name, size: sizeVal, bytes: bytes, path: path));
          }
          completer.complete();
        });
        reader.readAsArrayBuffer(f);
        tasks.add(completer.future);
      } catch (_) {
        // ignore
      }
    }
  }

  await Future.wait(tasks);
  return out;
}
