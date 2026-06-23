import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';

import '../../reliquary_service.dart';

class PdfPreview extends StatelessWidget {
  final String filePath;
  final ReliquaryService reliquary;

  const PdfPreview({
    super.key,
    required this.filePath,
    required this.reliquary,
  });

  Future<Uint8List> _fetchPdfBytes() async {
    final url = await reliquary.presignDownload(filePath);
    final response = await http.get(Uri.parse(url));
    return response.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _fetchPdfBytes(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return PdfViewer(
          PdfDocumentRefData(
            snap.data!,
            sourceName: filePath,
          ),
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
