import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';

import '../reliquary_service.dart';

class UploadScreen extends StatefulWidget {
  final ReliquaryService reliquary;

  const UploadScreen({super.key, required this.reliquary});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<PlatformFile> _selectedFiles = [];
  final Map<String, _UploadProgress> _progress = {};
  bool _uploading = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFiles = result.files;
        _progress.clear();
      });
    }
  }

  Future<void> _uploadAll() async {
    if (_selectedFiles.isEmpty) return;

    setState(() => _uploading = true);

    for (final file in _selectedFiles) {
      final name = file.name;
      setState(() {
        _progress[name] = _UploadProgress(status: 'Uploading...', fraction: 0);
      });

      try {
        final contentType =
            lookupMimeType(file.name) ?? 'application/octet-stream';

        List<int> bytes;
        if (file.bytes != null) {
          bytes = file.bytes!;
        } else if (!kIsWeb && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        } else {
          throw Exception('No file data available');
        }

        final result = await widget.reliquary.uploadFile(
          file.name,
          bytes,
          contentType,
          onProgress: (sent, total) {
            if (total > 0) {
              setState(() {
                _progress[name] = _UploadProgress(
                  status: 'Uploading...',
                  fraction: sent / total,
                );
              });
            }
          },
        );

        setState(() {
          _progress[name] = _UploadProgress(
            status: result.duplicate ? 'Duplicate skipped' : 'Done',
            fraction: 1.0,
            done: true,
          );
        });
      } catch (e) {
        setState(() {
          _progress[name] =
              _UploadProgress(status: 'Failed: $e', error: true);
        });
      }
    }

    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final allDone =
        _progress.isNotEmpty && _progress.values.every((p) => p.done);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 100,
              child: OutlinedButton(
                onPressed: _uploading ? null : _pickFiles,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file,
                        size: 28,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 6),
                    const Text('Select files'),
                  ],
                ),
              ),
            ),
            if (_selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_selectedFiles.length} file(s) selected',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _uploading ? null : _uploadAll,
                  child: Text(
                      _uploading
                          ? 'Uploading...'
                          : 'Upload (${_selectedFiles.length})',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _selectedFiles.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final file = _selectedFiles[index];
                  final progress = _progress[file.name];
                  return ListTile(
                    leading: Icon(
                      progress?.done == true
                          ? Icons.check_circle
                          : progress?.error == true
                              ? Icons.error
                              : Icons.insert_drive_file,
                      color: progress?.done == true
                          ? Colors.green
                          : progress?.error == true
                              ? Colors.redAccent
                              : null,
                      size: 20,
                    ),
                    title:
                        Text(file.name, style: const TextStyle(fontSize: 13)),
                    subtitle: progress != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(progress.status,
                                  style: Theme.of(context).textTheme.bodySmall),
                              if (progress.fraction != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: LinearProgressIndicator(
                                    value: progress.fraction,
                                  ),
                                ),
                            ],
                          )
                        : Text(_formatSize(file.size),
                            style: Theme.of(context).textTheme.bodySmall),
                  );
                },
              ),
            ),
            if (allDone)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
          ],
        ),
      ),
    );
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

  _UploadProgress({
    required this.status,
    this.fraction,
    this.done = false,
    this.error = false,
  });
}
