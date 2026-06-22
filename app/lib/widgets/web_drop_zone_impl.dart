// Web-only implementation of WebDropZone. Captures native DOM drop events
// and converts them into PlatformFile lists using expandDropItemsWeb.
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';
import '../services/drop_item_utils_web.dart';

class WebDropZone extends StatefulWidget {
  final Widget child;
  final void Function(List<PlatformFile>)? onDropFiles;
  final void Function(bool)? onHover;

  const WebDropZone({
    super.key,
    required this.child,
    this.onDropFiles,
    this.onHover,
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
      if (items == null) return;
      try {
        final files = await expandDropItemsWeb(items);
        if (files.isNotEmpty) widget.onDropFiles?.call(files);
      } catch (_) {}
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
