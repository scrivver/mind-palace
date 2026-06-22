import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';

import '../reliquary_service.dart';
import '../services/file_picker_service.dart' as picker;
import '../upload_file.dart';
import '../widgets/sidebar.dart';

class UploadScreen extends StatefulWidget {
  final ReliquaryService reliquary;
  final VoidCallback onLogout;
  final String username;

  const UploadScreen({
    super.key,
    required this.reliquary,
    required this.onLogout,
    required this.username,
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
          child: Row(
            children: [
              Sidebar(
                username: widget.username,
                onLogout: widget.onLogout,
              ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
                    child: Text('Upload Manager',
                        style: theme.textTheme.headlineMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Text(
                      'Import your digital assets into the Vault. We support encrypted transfer of documents, images, and neural mappings.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                  // Drop zone
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: InkWell(
                      onTap: _uploading || _pickingFiles ? null : _pickFiles,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 28,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Drag and drop files\nor click to browse your local sanctuary',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Max 250MB per file',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
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
                          if (!_uploading && !allDone)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedFiles.clear();
                                  _progress.clear();
                                });
                              },
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Clear'),
                            ),
                          if (allDone)
                            TextButton.icon(
                              onPressed: () =>
                                  Navigator.of(context).pop(),
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
          ],
        ),
      ),
    );
  }
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
                if (progress != null)
                  Text(
                    progress!.status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: isError
                          ? theme.colorScheme.error
                          : isDone
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Text(
                    _formatSize(file.size),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
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
