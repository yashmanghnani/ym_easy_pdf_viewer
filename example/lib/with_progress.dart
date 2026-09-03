import 'dart:async';

import 'package:ym_easy_pdf_viewer/ym_easy_pdf_viewer.dart';
import 'package:flutter/material.dart';

class WithProgress extends StatefulWidget {
  const WithProgress({super.key});

  @override
  State<WithProgress> createState() => _WithProgressState();
}

class _WithProgressState extends State<WithProgress> {
  bool _isLoading = true;
  late PDFDocument document;
  DownloadProgress? downloadProgress;
  StreamSubscription<FileResponse>? _subscription;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDocument());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _loadDocument() async {
    /// Clears the cache before download, so [PDFDocument.fromURLWithDownloadProgress.downloadProgress()]
    /// is always executed (meant only for testing).
    await DefaultCacheManager().emptyCache();

    _subscription = PDFDocument.fromURLWithDownloadProgress(
      'https://www.africau.edu/images/default/sample.pdf',
      downloadProgress: (progress) {
        if (mounted) setState(() => downloadProgress = progress);
      },
      onDownloadComplete: (loadedDocument) {
        if (mounted) {
          setState(() {
            document = loadedDocument;
            _isLoading = false;
          });
        }
      },
    );
  }

  Widget _buildProgress() {
    if (downloadProgress == null) return const SizedBox.shrink();

    String parseBytesToKBs(int bytes) {
      return '${(bytes / 1000).toStringAsFixed(2)} KBs';
    }

    String progressString = parseBytesToKBs(downloadProgress!.downloaded);
    if (downloadProgress!.totalSize != null) {
      progressString += '/ ${parseBytesToKBs(downloadProgress!.totalSize!)}';
    }

    return Column(children: [SizedBox(height: 20), Text(progressString)]);
  }

  Future<void> _changePDF(int value) async {
    setState(() => _isLoading = true);
    if (value == 1) {
      document = await PDFDocument.fromAsset('assets/sample2.pdf');
    } else if (value == 2) {
      document = await PDFDocument.fromURL(
        "https://www.africau.edu/images/default/sample.pdf",

        /* cacheManager: CacheManager(
          Config(
            "customCacheKey",
            stalePeriod: const Duration(days: 2),
            maxNrOfCacheObjects: 10,
          ),
        ), */
      );
    } else {
      document = await PDFDocument.fromAsset('assets/sample.pdf');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            SizedBox(height: 36),
            ListTile(
              title: Text('Load from Assets'),
              onTap: () {
                _changePDF(1);
              },
            ),
            ListTile(
              title: Text('Load from URL'),
              onTap: () {
                _changePDF(2);
              },
            ),
            ListTile(
              title: Text('Restore default'),
              onTap: () {
                _changePDF(3);
              },
            ),
            ListTile(
              title: Text('With Progress'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WithProgress()),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(title: const Text('PDFViewer')),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    _buildProgress(),
                  ],
                ),
              )
            : PDFViewer(
                document: document,
                numberPickerConfirmWidget: const Text("Confirm"),
              ),
      ),
    );
  }
}
