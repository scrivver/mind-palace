import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:desktop_drop/desktop_drop.dart'
    if (dart.library.html) 'package:mind_palace/widgets/drop_target_stub.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import '../services/drop_item_utils.dart';
import '../upload_file.dart';
import '../widgets/web_drop_zone.dart' as web_drop;

import '../providers/service_providers.dart';
import '../providers/upload_provider.dart';
import '../services/file_picker_service.dart' as picker;
import '../widgets/upload/dashed_border_painter.dart';
import '../widgets/upload/upload_file_tile.dart';
import '../widgets/upload/upload_progress.dart';

class UploadScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const UploadScreen({
    super.key,
    this.onBack,
  });

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  bool _isDragging = false;

  String _key(PlatformFile f) => UploadNotifier.key(f);

  Future<void> _onDropItems(List<dynamic> items) async {
    final files = <PlatformFile>[];

    try {
      if (!kIsWeb) {
        final expanded = await expandDropItemsIo(items as dynamic);
        files.addAll(expanded);
      } else {
        for (final item in items) {
          try {
            final bytes = await (item as dynamic).readAsBytes();
            final size = await (item as dynamic).length();
            files.add(
              PlatformFile(
                name: (item as dynamic).name as String,
                size: size as int,
                bytes: bytes as Uint8List,
                path: (item as dynamic).path as String?,
              ),
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      for (final item in items) {
        try {
          final bytes = await item.readAsBytes();
          final size = await item.length();
          files.add(
            PlatformFile(
              name: item.name,
              size: size,
              bytes: bytes,
              path: item.path,
            ),
          );
        } catch (_) {}
      }
    }

    if (!mounted) return;
    bool _isPlaceholder(PlatformFile f) {
      final name = f.name;
      final path = f.path;
      if (name.startsWith('.inode') || name == 'x-empty') return true;
      if (path != null && path.contains('.inode')) return true;
      return false;
    }

    final nonPlaceholders = files.where((f) => !_isPlaceholder(f)).toList();
    if (nonPlaceholders.isEmpty && files.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Folder drop is not supported in this browser or produced no files. Please use "Select Folder".',
          ),
        ),
      );
      setState(() => _isDragging = false);
      return;
    }

    ref.read(uploadProvider.notifier).addFiles(nonPlaceholders);
    setState(() => _isDragging = false);
  }

  Future<dynamic> importDropItemUtilsIo() async {
    return await Future.value(
      (() async {
        return {
          'expandDropItemsIo': (List<dynamic> items) async =>
              await expandDropItemsIo(items),
        };
      })(),
    );
  }

  Future<void> _pickFiles() async {
    try {
      if (!mounted) return;
      final result = await picker.pickFiles(allowMultiple: true);
      if (result != null && result.isNotEmpty) {
        if (!mounted) return;
        ref.read(uploadProvider.notifier).addFiles(result);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick files: $e')));
    }
  }

  Future<void> _pickFolder() async {
    try {
      final result = await picker.pickFolder();
      if (result != null && result.isNotEmpty) {
        if (!mounted) return;
        ref.read(uploadProvider.notifier).addFiles(result);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick folder: $e')));
    }
  }

  Future<void> _uploadAll() async {
    final snapshotFiles =
        List<PlatformFile>.from(ref.read(uploadProvider).selectedFiles);
    if (snapshotFiles.isEmpty) return;

    final notifier = ref.read(uploadProvider.notifier);
    notifier.setUploading(true);

    for (final file in snapshotFiles) {
      final k = _key(file);

      notifier.setProgress(
          k, const UploadProgress(status: 'Initializing...', fraction: 0));

      try {
        final contentType =
            lookupMimeType(file.name) ?? 'application/octet-stream';

        final bytes = await readPlatformFileBytes(file);

        notifier.setProgress(
            k, const UploadProgress(status: 'Uploading...', fraction: 0));

        final reliquary = ref.read(reliquaryServiceProvider).valueOrNull;
        if (reliquary == null) continue;

        final result = await reliquary.uploadFile(
          file.name,
          bytes,
          contentType,
          onProgress: (sent, total) {
            if (total > 0) {
              notifier.setProgress(
                k,
                UploadProgress(
                  status: 'Uploading...',
                  fraction: sent / total,
                ),
              );
            }
          },
        );

        notifier.setProgress(
          k,
          UploadProgress(
            status: result.duplicate ? 'Duplicate skipped' : 'Synced',
            fraction: 1.0,
            done: true,
            isDuplicate: result.duplicate,
          ),
        );
      } catch (e) {
        notifier.setProgress(
            k, UploadProgress(status: 'Failed: $e', error: true));
      }
    }

    if (!mounted) return;
    notifier.setUploading(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uploadState = ref.watch(uploadProvider);
    final selectedFiles = uploadState.selectedFiles;
    final progressMap = uploadState.progressMap;
    final isUploading = uploadState.isUploading;
    final allDone =
        progressMap.isNotEmpty && progressMap.values.every((p) => p.done);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed:
                        widget.onBack ?? () => Navigator.of(context).pop(),
                  ),
                  Text('Upload Assets', style: theme.textTheme.headlineMedium),
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: kIsWeb
                  ? web_drop.WebDropZone(
                      onDropFiles: (files) async {
                        if (!mounted) return;
                        ref
                            .read(uploadProvider.notifier)
                            .addFiles(files);
                        setState(() => _isDragging = false);
                      },
                      onHover: (hovering) {
                        if (!isUploading) {
                          setState(() => _isDragging = hovering);
                        }
                      },
                      onDropFolder: () async {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Drag-and-drop is not fully supported in this browser. Please use "Select Folder" to add folder contents.',
                            ),
                          ),
                        );
                      },
                      child: InkWell(
                        onTap: isUploading ? null : _pickFiles,
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
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
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
                                        onPressed:
                                            isUploading ? null : _pickFiles,
                                        child: const Text('Select Files'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed:
                                            isUploading ? null : _pickFolder,
                                        icon: const Icon(
                                          Icons.folder_open,
                                          size: 18,
                                        ),
                                        label: const Text('Select Folder'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : DropTarget(
                      onDragDone: (details) => _onDropItems(details.files),
                      onDragEntered: (_) {
                        if (!isUploading) {
                          setState(() => _isDragging = true);
                        }
                      },
                      onDragExited: (_) {
                        if (_isDragging) setState(() => _isDragging = false);
                      },
                      child: InkWell(
                        onTap: isUploading ? null : _pickFiles,
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
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
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
                                        onPressed:
                                            isUploading ? null : _pickFiles,
                                        child: const Text('Select Files'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed:
                                            isUploading ? null : _pickFolder,
                                        icon: const Icon(
                                          Icons.folder_open,
                                          size: 18,
                                        ),
                                        label: const Text('Select Folder'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),

            if (selectedFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Text(
                      'Queue (${selectedFiles.length})',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(uploadProvider.notifier).clearAll(),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Clear All'),
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

            if (selectedFiles.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: selectedFiles.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final file = selectedFiles[index];
                    final p = progressMap[_key(file)];
                    return UploadFileTile(
                      file: file,
                      progress: p,
                      onRemove: isUploading
                          ? null
                          : () =>
                              ref
                                  .read(uploadProvider.notifier)
                                  .removeFile(_key(file)),
                    );
                  },
                ),
              ),

            if (selectedFiles.isNotEmpty && !allDone && !isUploading)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: isUploading ? null : _uploadAll,
                    child: Text('Process All (${selectedFiles.length})'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
