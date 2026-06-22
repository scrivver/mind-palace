// Web-only implementation of WebDropZone. Captures native DOM drop events
// and converts them into PlatformFile lists using expandDropItemsWeb.
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';
import '../services/drop_item_utils_web.dart';

class WebDropZone extends StatefulWidget {
  final Widget child;
  final void Function(List<PlatformFile>)? onDropFiles;
  final void Function(bool)? onHover;
  final void Function()? onDropFolder;

  const WebDropZone({
    super.key,
    required this.child,
    this.onDropFiles,
    this.onHover,
    this.onDropFolder,
  });

  @override
  State<WebDropZone> createState() => _WebDropZoneState();
}

class _WebDropZoneState extends State<WebDropZone> {
  static int _idCounter = 0;
  late final String _viewId;
  late StreamSubscription<html.Event> _windowDragEnterSub;
  late StreamSubscription<html.Event> _windowDragOverSub;
  late StreamSubscription<html.Event> _windowDragLeaveSub;
  late StreamSubscription<html.Event> _windowDropSub;

  @override
  void initState() {
    super.initState();
    _viewId = 'web-drop-zone-${_idCounter++}';

    // Track drags on the document body. Listening on document.body is more
    // reliable for file drag events from the OS into the browser.
    int dragCounter = 0;
    final body = html.document.body!;
    _windowDragEnterSub = body.onDragEnter.listen((e) {
      dragCounter++;
      widget.onHover?.call(true);
    });
    _windowDragOverSub = body.onDragOver.listen((e) {
      // Allow drop by preventing default
      e.preventDefault();
    });
    _windowDragLeaveSub = body.onDragLeave.listen((e) {
      dragCounter = (dragCounter - 1).clamp(0, 9999);
      if (dragCounter == 0) {
        widget.onHover?.call(false);
      }
    });

    _windowDropSub = body.onDrop.listen((e) async {
      e.preventDefault();
      dragCounter = 0;
      widget.onHover?.call(false);
      final items = e.dataTransfer?.items;
      final fileList = e.dataTransfer?.files;

      final itemsLen = items?.length ?? 0;
      final fileListLen = fileList?.length ?? 0;

      // Prefer entry traversal and the item-based expansion first. This
      // ensures Chromium's FileSystemEntry/webkitGetAsEntry path is used
      // when available and preserves folder structure automatically.
      try {
        if ((items?.length ?? 0) > 0) {
          final files = await expandDropItemsWeb(items as html.DataTransferItemList);
          if (files.isNotEmpty) {
            widget.onDropFiles?.call(files);
            return;
          }
        }

        // Fall back to reading the FileList (files) which many browsers
        // populate with the dropped files and may include webkitRelativePath.
        if ((fileList?.length ?? 0) > 0) {
          final result = <PlatformFile>[];
          final futures = <Future<void>>[];
          for (var i = 0; i < fileList!.length; i++) {
            final f = fileList[i] as html.File;
            final completer = Completer<void>();
            final reader = html.FileReader();
            reader.onLoadEnd.listen((_) {
              final r = reader.result;
              Uint8List bytes;
              if (r is ByteBuffer) {
                bytes = Uint8List.view(r);
              } else if (r is List<int>) {
                bytes = Uint8List.fromList(r);
              } else {
                bytes = Uint8List(0);
              }
              String? rel;
              try {
                final dyn = f as dynamic;
                final v = dyn.webkitRelativePath;
                if (v is String && v.isNotEmpty) rel = v;
              } catch (_) {
                rel = null;
              }
              result.add(PlatformFile(name: rel ?? f.name, size: f.size, bytes: bytes, path: rel));
              completer.complete();
            });
            reader.onError.listen((_) => completer.complete());
            try {
              reader.readAsArrayBuffer(f);
            } catch (_) {
              completer.complete();
            }
            futures.add(completer.future);
          }
          await Future.wait(futures);
          if (result.isNotEmpty) {
            widget.onDropFiles?.call(result);
            return;
          }
        }
      } catch (_) {
        // Ignore and fallback to folder handler below.
      }

      // No files enumerated — likely a folder drop on an unsupported browser.
      widget.onDropFolder?.call();
    });

    // No platform view registration necessary when using window-level
    // drag/drop events.
  }

  @override
  void dispose() {
    _windowDragEnterSub.cancel();
    _windowDragOverSub.cancel();
    _windowDragLeaveSub.cancel();
    _windowDropSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
      ],
    );
  }
}
