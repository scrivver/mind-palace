import 'package:desktop_drop/desktop_drop.dart'
    if (dart.library.html) 'package:mind_palace/widgets/drop_target_stub.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../web_drop_zone.dart' as web_drop;
import 'dashed_border_painter.dart';

/// Drop zone with localized hover state.
///
/// Encapsulates the platform-specific drop target (web [WebDropZone] vs native
/// [DropTarget]) and the drag-hover animation so the parent screen does not
/// rebuild on every enter/exit event.
class UploadDropZone extends StatefulWidget {
  final bool isUploading;
  final void Function(List<dynamic> items) onDropItems;
  final void Function(List<PlatformFile> files) onDropFiles;
  final VoidCallback onPickFiles;
  final VoidCallback onPickFolder;
  final VoidCallback? onWebDropFolder;

  const UploadDropZone({
    super.key,
    required this.isUploading,
    required this.onDropItems,
    required this.onDropFiles,
    required this.onPickFiles,
    required this.onPickFolder,
    this.onWebDropFolder,
  });

  @override
  State<UploadDropZone> createState() => _UploadDropZoneState();
}

class _UploadDropZoneState extends State<UploadDropZone> {
  bool _isDragging = false;

  void _setDragging(bool value) {
    if (widget.isUploading) return;
    if (_isDragging == value) return;
    setState(() => _isDragging = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = _buildContent(context);

    if (kIsWeb) {
      return web_drop.WebDropZone(
        onDropFiles: (files) {
          _setDragging(false);
          widget.onDropFiles(files);
        },
        onHover: (hovering) => _setDragging(hovering),
        onDropFolder: widget.onWebDropFolder,
        child: InkWell(
          onTap: widget.isUploading ? null : widget.onPickFiles,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              foregroundPainter: DashedBorderPainter(
                color: _isDragging
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _isDragging
                      ? theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
                child: content,
              ),
            ),
          ),
        ),
      );
    }

    return DropTarget(
      onDragDone: (details) {
        _setDragging(false);
        widget.onDropItems(details.files);
      },
      onDragEntered: (_) => _setDragging(true),
      onDragExited: (_) => _setDragging(false),
      child: InkWell(
        onTap: widget.isUploading ? null : widget.onPickFiles,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            foregroundPainter: DashedBorderPainter(
              color: _isDragging
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _isDragging
                    ? theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _isDragging
                ? theme.colorScheme.primary
                : theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add_circle,
            size: 36,
            color: _isDragging
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isDragging ? 'Drop files here' : 'Click to select or drag files',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'PDF, Markdown, JSON, and high-res images (Max 100MB)',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton(
              onPressed: widget.isUploading ? null : widget.onPickFiles,
              child: const Text('Select Files'),
            ),
            OutlinedButton.icon(
              onPressed: widget.isUploading ? null : widget.onPickFolder,
              icon: const Icon(
                Icons.folder_open,
                size: 18,
              ),
              label: const Text('Select Folder'),
            ),
          ],
        ),
      ],
    );
  }
}
