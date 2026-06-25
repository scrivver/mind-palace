// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';
import '../services/drop_item_utils_web.dart'
    show captureDropEntries, expandCapturedDrop;

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
  late StreamSubscription<html.Event> _windowDragEnterSub;
  late StreamSubscription<html.Event> _windowDragOverSub;
  late StreamSubscription<html.Event> _windowDragLeaveSub;
  late StreamSubscription<html.Event> _windowDropSub;

  @override
  void initState() {
    super.initState();

    int dragCounter = 0;
    final body = html.document.body!;
    _windowDragEnterSub = body.onDragEnter.listen((e) {
      dragCounter++;
      widget.onHover?.call(true);
    });
    _windowDragOverSub = body.onDragOver.listen((e) {
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

      final dataTransfer = e.dataTransfer;
      final items = dataTransfer.items;

      if ((items?.length ?? 0) > 0) {
        // Capture entry objects synchronously, before any await. Firefox
        // invalidates DataTransfer objects once the event handler yields.
        final captured = captureDropEntries(items);

        if (captured.entries.isNotEmpty || captured.files.isNotEmpty) {
          try {
            final files = await expandCapturedDrop(captured);
            if (files.isNotEmpty) {
              widget.onDropFiles?.call(files);
              return;
            }
          } catch (_) {}
        }
      }

      // Entry traversal failed — browser too old or dropped content isn't
      // readable via drag/drop. Show a message asking the user to use the
      // "Select Folder" button instead.
      widget.onDropFolder?.call();
    });
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
    return Stack(fit: StackFit.passthrough, children: [widget.child]);
  }
}
