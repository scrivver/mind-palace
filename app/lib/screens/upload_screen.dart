import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import '../models/picked_file.dart';
import '../services/drop_item_utils.dart';
import '../upload_file.dart';
import '../providers/service_providers.dart';
import '../providers/upload_provider.dart';
import '../services/file_picker_service.dart' as picker;
import '../utils/breakpoints.dart';
import '../widgets/upload/upload_drop_zone.dart';
import '../widgets/upload/upload_file_tile.dart';
import '../widgets/upload/upload_progress.dart';

class UploadScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const UploadScreen({super.key, this.onBack});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  String _key(PickedFile f) => UploadNotifier.key(f);

  Future<void> _onDropItems(List<dynamic> items) async {
    final files = <PickedFile>[];

    try {
      if (!kIsWeb) {
        final expanded = await expandDropItemsIo(items as dynamic);
        files.addAll(expanded);
      } else {
        for (final item in items) {
          try {
            final bytes = await (item as dynamic).readAsBytes();
            final size = await (item as dynamic).length();
            // A loose dropped item carries no folder context; only the
            // directory walk in expandCapturedDrop can supply one.
            files.add(
              PickedFile(
                PlatformFile(
                  name: (item as dynamic).name as String,
                  size: size as int,
                  bytes: bytes as Uint8List,
                ),
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
            PickedFile(PlatformFile(name: item.name, size: size, bytes: bytes)),
          );
        } catch (_) {}
      }
    }

    if (!mounted) return;
    bool isPlaceholder(PickedFile f) {
      final name = f.name;
      final relative = f.relativePath;
      if (name.startsWith('.inode') || name == 'x-empty') return true;
      if (relative != null && relative.contains('.inode')) return true;
      return false;
    }

    final nonPlaceholders = files.where((f) => !isPlaceholder(f)).toList();
    if (nonPlaceholders.isEmpty && files.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Folder drop is not supported in this browser or produced no files. Please use "Select Folder".',
          ),
        ),
      );
      return;
    }

    ref.read(uploadProvider.notifier).addFiles(nonPlaceholders);
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
    final snapshotFiles = List<PickedFile>.from(
      ref.read(uploadProvider).selectedFiles,
    );
    if (snapshotFiles.isEmpty) return;

    final notifier = ref.read(uploadProvider.notifier);
    notifier.setUploading(true);

    for (final file in snapshotFiles) {
      final k = _key(file);

      notifier.setProgress(
        k,
        const UploadProgress(status: 'Initializing...', fraction: 0),
      );

      try {
        final contentType =
            lookupMimeType(file.name) ?? 'application/octet-stream';

        final bytes = await readPlatformFileBytes(file.file);

        notifier.setProgress(
          k,
          const UploadProgress(status: 'Uploading...', fraction: 0),
        );

        final reliquary = ref.read(reliquaryServiceProvider).valueOrNull;
        if (reliquary == null) continue;

        final result = await reliquary.uploadFile(
          file.name,
          bytes,
          contentType,
          // Preserves the folder the user picked or dropped. Null for a plain
          // file selection, and never a filesystem path.
          relativePath: file.relativePath,
          onProgress: (sent, total) {
            if (total > 0) {
              notifier.setProgress(
                k,
                UploadProgress(status: 'Uploading...', fraction: sent / total),
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
          k,
          UploadProgress(status: 'Failed: $e', error: true),
        );
      }
    }

    if (!mounted) return;
    notifier.setUploading(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedFiles = ref.watch(
      uploadProvider.select((s) => s.selectedFiles),
    );
    final progressMap = ref.watch(uploadProvider.select((s) => s.progressMap));
    final isUploading = ref.watch(uploadProvider.select((s) => s.isUploading));
    final allDone =
        progressMap.isNotEmpty && progressMap.values.every((p) => p.done);

    final isMobile = isMobileWidth(context);
    final gutter = isMobile ? 16.0 : 24.0;

    return Scaffold(
      // The shell hides its navigation bar here, so the back button lives in
      // this screen's own app bar rather than in the scrolling content.
      appBar: isMobile
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
              ),
              title: const Text('Upload Assets'),
            )
          : null,
      body: SafeArea(
        top: !isMobile,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMobile)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed:
                          widget.onBack ?? () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'Upload Assets',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                isMobile ? 16 : 0,
                gutter,
                16,
              ),
              child: Text(
                'Integrate new knowledge into your Mind Palace. Supports documents, images, and neural mappings.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: UploadDropZone(
                isUploading: isUploading,
                compact: isMobile,
                onDropItems: _onDropItems,
                onDropFiles: (files) =>
                    ref.read(uploadProvider.notifier).addFiles(files),
                onPickFiles: _pickFiles,
                onPickFolder: _pickFolder,
                onWebDropFolder: kIsWeb
                    ? () {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Drag-and-drop is not fully supported in this browser. Please use "Select Folder" to add folder contents.',
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ),

            if (selectedFiles.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 8),
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
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  itemCount: selectedFiles.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final file = selectedFiles[index];
                    final p = progressMap[_key(file)];
                    return UploadFileTile(
                      key: ValueKey(_key(file)),
                      file: file.file,
                      label: file.relativePath,
                      progress: p,
                      onRemove: isUploading
                          ? null
                          : () => ref
                                .read(uploadProvider.notifier)
                                .removeFile(_key(file)),
                    );
                  },
                ),
              ),

            if (selectedFiles.isNotEmpty && !allDone && !isUploading)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  12,
                  gutter,
                  isMobile ? 16 : 24,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: isMobile ? 48 : 44,
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
