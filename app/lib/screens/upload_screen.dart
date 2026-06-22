import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';

import '../reliquary_service.dart';
import '../services/file_picker_service.dart' as picker;
import '../upload_file.dart';

class UploadScreen extends StatefulWidget {
  final ReliquaryService reliquary;
  final VoidCallback onLogout;
  final String username;
  final VoidCallback? onBack;

  const UploadScreen({
    super.key,
    required this.reliquary,
    required this.onLogout,
    required this.username,
    this.onBack,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<PlatformFile> _selectedFiles = [];
  final Map<String, _UploadProgress> _progress = {};
  bool _uploading = false;

  String _key(PlatformFile f) => '${f.name}::${f.hashCode}';

  bool _pickingFiles = false;
  bool _isDragging = false;

  Future<void> _onDropItems(List<DropItem> items) async {
    final files = <PlatformFile>[];
    for (final item in items) {
      final bytes = await item.readAsBytes();
      final size = await item.length();
      files.add(PlatformFile(
        name: item.name,
        size: size,
        bytes: bytes,
        path: item.path,
      ));
    }
    if (!mounted) return;
    setState(() {
      _selectedFiles = files;
      _progress.clear();
      _isDragging = false;
    });
  }

  Future<void> _pickFiles() async {
    if (_pickingFiles) return;
    setState(() => _pickingFiles = true);

    try {
      for (int attempt = 0; attempt < 2; attempt++) {
        if (!mounted) return;
        final result = await picker.pickFiles(allowMultiple: true);
        if (result != null && result.isNotEmpty) {
          setState(() {
            _selectedFiles = result;
            _progress.clear();
            _pickingFiles = false;
          });
          return;
        }
        if (!mounted) return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No files selected. Tap "Select files" to try again.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick files: $e')),
      );
    }

    if (!mounted) return;
    setState(() => _pickingFiles = false);
  }

  Future<void> _uploadAll() async {
    if (_selectedFiles.isEmpty) return;

    setState(() => _uploading = true);

    for (final file in _selectedFiles) {
      final k = _key(file);

      if (!mounted) return;
      setState(() {
        _progress[k] = _UploadProgress(status: 'Initializing...', fraction: 0);
      });

      try {
        final contentType =
            lookupMimeType(file.name) ?? 'application/octet-stream';

        final bytes = await readPlatformFileBytes(file);

        if (!mounted) return;
        setState(() {
          _progress[k] =
              _UploadProgress(status: 'Uploading...', fraction: 0);
        });

        final result = await widget.reliquary.uploadFile(
          file.name,
          bytes,
          contentType,
          onProgress: (sent, total) {
            if (!mounted) return;
            if (total > 0) {
              setState(() {
                _progress[k] = _UploadProgress(
                  status: 'Uploading...',
                  fraction: sent / total,
                );
              });
            }
          },
        );

        if (!mounted) return;
        setState(() {
          _progress[k] = _UploadProgress(
            status: result.duplicate ? 'Duplicate skipped' : 'Synced',
            fraction: 1.0,
            done: true,
            isDuplicate: result.duplicate,
          );
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _progress[k] =
              _UploadProgress(status: 'Failed: $e', error: true);
        });
      }
    }

    if (!mounted) return;
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allDone =
        _progress.isNotEmpty && _progress.values.every((p) => p.done);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                  ),
                  Text('Upload Assets',
                      style: theme.textTheme.headlineMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                'Integrate new knowledge into your Mind Palace. Supports documents, images, and neural mappings.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          // Upload zone
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: DropTarget(
              onDragDone: (details) => _onDropItems(details.files),
              onDragEntered: (_) {
                if (!_uploading) setState(() => _isDragging = true);
              },
              onDragExited: (_) {
                if (_isDragging) setState(() => _isDragging = false);
              },
              child: InkWell(
                onTap: _uploading || _pickingFiles ? null : _pickFiles,
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    foregroundPainter: _DashedBorderPainter(
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
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                      child: Column(
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
                            _isDragging
                                ? 'Drop files here'
                                : 'Click to select or drag files',
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
                          FilledButton(
                            onPressed: _uploading || _pickingFiles
                                ? null
                                : _pickFiles,
                            child: const Text('Select Files'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

            // Queue header
            if (_selectedFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Text(
                      'Queue (${_selectedFiles.length})',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedFiles.clear();
                          _progress.clear();
                        });
                      },
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Clear Completed'),
                    ),
                    if (allDone)
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Done'),
                      ),
                  ],
                ),
              ),

            // File list
            if (_selectedFiles.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _selectedFiles.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  itemBuilder: (context, index) {
                    final file = _selectedFiles[index];
                    final p = _progress[_key(file)];
                    return _UploadFileTile(
                      file: file,
                      progress: p,
                    );
                  },
                ),
              ),

            // Upload button
            if (_selectedFiles.isNotEmpty && !allDone && !_uploading)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed:
                        _uploading || _pickingFiles ? null : _uploadAll,
                    child: Text('Process All (${_selectedFiles.length})'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashLength = 6,
    this.gapLength = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0, metric.length) as double;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}

class _UploadFileTile extends StatelessWidget {
  final PlatformFile file;
  final _UploadProgress? progress;

  const _UploadFileTile({
    required this.file,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = progress?.done == true;
    final isError = progress?.error == true;
    final isDuplicate = progress?.isDuplicate == true;
    final isUploading = progress != null && !isDone && !isError;

    IconData leadingIcon;
    Color? iconColor;
    if (isDone) {
      leadingIcon = isDuplicate ? Icons.content_copy : Icons.check_circle;
      iconColor = isDuplicate
          ? theme.colorScheme.tertiary
          : theme.colorScheme.primary;
    } else if (isError) {
      leadingIcon = Icons.error;
      iconColor = theme.colorScheme.error;
    } else {
      leadingIcon = _iconForName(file.name);
      iconColor = theme.colorScheme.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(leadingIcon, size: 22, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatSize(file.size)} • ${progress?.status ?? "Pending"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: isError
                        ? theme.colorScheme.error
                        : isDone
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isUploading && progress!.fraction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(
                      value: progress!.fraction,
                      minHeight: 3,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isDone)
            Icon(Icons.more_vert,
                size: 16, color: theme.colorScheme.onSurfaceVariant)
          else if (isError)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Retry',
              onPressed: () {},
              visualDensity: VisualDensity.compact,
            )
          else
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove',
              onPressed: () {},
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  IconData _iconForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.svg')) {
      return Icons.image;
    }
    if (lower.endsWith('.md') || lower.endsWith('.txt')) {
      return Icons.description;
    }
    if (lower.endsWith('.json') ||
        lower.endsWith('.js') ||
        lower.endsWith('.py') ||
        lower.endsWith('.dart') ||
        lower.endsWith('.html')) {
      return Icons.terminal;
    }
    if (lower.endsWith('.xlsx') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.numbers')) {
      return Icons.table_chart;
    }
    return Icons.insert_drive_file;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _UploadProgress {
  final String status;
  final double? fraction;
  final bool done;
  final bool error;
  final bool isDuplicate;

  _UploadProgress({
    required this.status,
    this.fraction,
    this.done = false,
    this.error = false,
    this.isDuplicate = false,
  });
}
