import 'package:flutter/widgets.dart';
import 'dart:typed_data';

/// Minimal DropItem stub used on web builds. The real DropItem type comes
/// from the desktop_drop package on desktop builds. We only provide the
/// methods the app needs when compiled for web.
abstract class DropItem {
  String get name;
  String? get path;
  Future<Uint8List> readAsBytes();
  Future<int> length();
}

/// Stub DropTarget for web builds where desktop_drop is not available.
/// The real desktop_drop package is used on desktop (io) builds.
class DropTarget extends StatelessWidget {
  final Widget child;
  final void Function(dynamic)? onDragDone;
  final void Function(dynamic)? onDragEntered;
  final void Function(dynamic)? onDragExited;

  const DropTarget({
    super.key,
    required this.child,
    this.onDragDone,
    this.onDragEntered,
    this.onDragExited,
  });

  @override
  Widget build(BuildContext context) => child;
}
