import 'package:flutter/widgets.dart';
import '../models/picked_file.dart';

/// Stub implementation for non-web platforms. Simply forwards the child and
/// does not perform any special drop handling.
class WebDropZone extends StatelessWidget {
  final Widget child;
  final void Function(List<PickedFile>)? onDropFiles;
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
  Widget build(BuildContext context) => child;
}
