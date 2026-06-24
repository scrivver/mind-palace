import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';

import '../../reliquary_service.dart';
import '../../utils/preview_cache.dart';

class PdfPreview extends StatefulWidget {
  final String filePath;
  final ReliquaryService reliquary;

  const PdfPreview({
    super.key,
    required this.filePath,
    required this.reliquary,
  });

  @override
  State<PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  static final _cache = PreviewCache();
  Future<Uint8List>? _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _loadBytes();
  }

  @override
  void didUpdateWidget(PdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.reliquary != widget.reliquary) {
      _bytesFuture = _loadBytes();
    }
  }

  Future<Uint8List> _loadBytes() {
    return _cache.pdfBytes(widget.filePath, () async {
      final url = await widget.reliquary.presignDownload(widget.filePath);
      final response = await http.get(Uri.parse(url));
      return response.bodyBytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return PdfViewer(
          PdfDocumentRefData(snap.data!, sourceName: widget.filePath),
          params: PdfViewerParams(
            backgroundColor: const Color(0xFFFAFAFA),
            errorBannerBuilder: (_, error, stackTrace, ref) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load PDF',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
