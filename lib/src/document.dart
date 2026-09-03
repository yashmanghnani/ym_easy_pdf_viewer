import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'page.dart';

/// Error thrown when a PDF cannot be loaded or rendered.
class PDFDocumentException implements Exception {
  const PDFDocumentException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'PDFDocumentException: $message'
      : 'PDFDocumentException: $message ($cause)';
}

/// A loaded PDF document.
class PDFDocument {
  PDFDocument._({required this._filePath, required this.count});

  static const MethodChannel _channel = MethodChannel('easy_pdf_viewer_plugin');

  final String _filePath;
  final int count;
  final List<PDFPage?> _pages = <PDFPage?>[];

  /// The local path used to read the PDF.
  String get filePath => _filePath;

  static Future<PDFDocument> _fromPath(
    String path, {
    required bool clearPreviewCache,
  }) async {
    try {
      final Object? rawPageCount = await _channel.invokeMethod<Object?>(
        'getNumberOfPages',
        <String, Object?>{'filePath': path, 'clearCacheDir': clearPreviewCache},
      );
      final int pageCount = _parsePageCount(rawPageCount);
      if (pageCount < 1) {
        throw const PDFDocumentException('The PDF does not contain any pages.');
      }
      return PDFDocument._(filePath: path, count: pageCount);
    } on PDFDocumentException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PDFDocumentException('Unable to read PDF at "$path".', cause: error),
        stackTrace,
      );
    }
  }

  static int _parsePageCount(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final int? parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw const PDFDocumentException(
      'The native PDF renderer returned an invalid page count.',
    );
  }

  /// Loads a PDF from a local [file].
  static Future<PDFDocument> fromFile(
    File file, {
    bool clearPreviewCache = true,
  }) async {
    if (!await file.exists()) {
      throw PDFDocumentException('PDF file does not exist: ${file.path}');
    }
    return _fromPath(file.path, clearPreviewCache: clearPreviewCache);
  }

  /// Downloads and loads a PDF from [url].
  static Future<PDFDocument> fromURL(
    String url, {
    Map<String, String>? headers,
    CacheManager? cacheManager,
    bool clearPreviewCache = true,
  }) async {
    try {
      final File file = await (cacheManager ?? DefaultCacheManager())
          .getSingleFile(url, headers: headers);
      return await _fromPath(file.path, clearPreviewCache: clearPreviewCache);
    } on PDFDocumentException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PDFDocumentException(
          'Unable to download PDF from "$url".',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  /// Downloads a PDF and reports progress until [onDownloadComplete] fires.
  ///
  /// The returned subscription can be cancelled when the owning screen is
  /// disposed or the request is no longer needed.
  static StreamSubscription<FileResponse> fromURLWithDownloadProgress(
    String url, {
    Map<String, String>? headers,
    CacheManager? cacheManager,
    bool clearPreviewCache = true,
    required void Function(DownloadProgress downloadProgress) downloadProgress,
    required void Function(PDFDocument document) onDownloadComplete,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    late final StreamSubscription<FileResponse> subscription;
    bool completed = false;
    final Stream<FileResponse> responses =
        (cacheManager ?? DefaultCacheManager()).getFileStream(
          url,
          headers: headers,
          withProgress: true,
        );

    Future<void> complete(File file) async {
      try {
        final PDFDocument document = await fromFile(
          file,
          clearPreviewCache: clearPreviewCache,
        );
        onDownloadComplete(document);
      } catch (error, stackTrace) {
        onError?.call(error, stackTrace);
      } finally {
        await subscription.cancel();
      }
    }

    subscription = responses.listen(
      (FileResponse response) {
        if (response is DownloadProgress) {
          downloadProgress(response);
          return;
        }
        if (response is FileInfo && !completed) {
          completed = true;
          unawaited(complete(response.file));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        onError?.call(error, stackTrace);
      },
    );
    return subscription;
  }

  /// Copies an asset PDF to application storage and loads it.
  static Future<PDFDocument> fromAsset(
    String asset, {
    bool clearPreviewCache = true,
  }) async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      final String fileName = asset
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
          .replaceFirst(RegExp(r'^_+'), '');
      final String assetId = asset.hashCode.toUnsigned(32).toRadixString(16);
      final File file = File(
        '${directory.path}/ym_easy_pdf_viewer_${assetId}_$fileName',
      );
      final ByteData data = await rootBundle.load(asset);
      final Uint8List bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await file.writeAsBytes(bytes, flush: true);
      return await _fromPath(file.path, clearPreviewCache: clearPreviewCache);
    } on PDFDocumentException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PDFDocumentException(
          'Unable to load PDF asset "$asset".',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  /// Clears rendered page previews from the native cache.
  static Future<void> clearPreviewCache() async {
    try {
      await _channel.invokeMethod<void>('clearCacheDir');
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PDFDocumentException(
          'Unable to clear the PDF preview cache.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  /// Loads one page, using the in-memory page cache when available.
  Future<PDFPage> get({
    int page = 1,
    ValueChanged<double>? onZoomChanged,
    int? zoomSteps,
    double? minScale,
    double? maxScale,
    double? panLimit,
  }) async {
    RangeError.checkValueInInterval(page, 1, count, 'page');
    final int index = page - 1;
    final PDFPage? cachedPage = index < _pages.length ? _pages[index] : null;
    if (cachedPage != null) return cachedPage;

    final Object? data = await _channel.invokeMethod<Object?>(
      'getPage',
      <String, Object?>{'filePath': _filePath, 'pageNumber': page},
    );
    final PDFPage loadedPage = PDFPage(
      data as String?,
      page,
      onZoomChanged: onZoomChanged,
      zoomSteps: zoomSteps ?? 3,
      minScale: minScale ?? 1.0,
      maxScale: maxScale ?? 5.0,
      panLimit: panLimit ?? 1.0,
    );
    while (_pages.length <= index) {
      _pages.add(null);
    }
    _pages[index] = loadedPage;
    return loadedPage;
  }

  /// Loads every page into the document's page cache.
  Future<void> preloadPages({
    ValueChanged<double>? onZoomChanged,
    int? zoomSteps,
    double? minScale,
    double? maxScale,
    double? panLimit,
  }) async {
    for (int page = 1; page <= count; page++) {
      await get(
        page: page,
        onZoomChanged: onZoomChanged,
        zoomSteps: zoomSteps,
        minScale: minScale,
        maxScale: maxScale,
        panLimit: panLimit,
      );
    }
  }

  /// Streams pages in document order.
  Stream<PDFPage> getAll({ValueChanged<double>? onZoomChanged}) async* {
    for (int page = 1; page <= count; page++) {
      yield await get(page: page, onZoomChanged: onZoomChanged);
    }
  }
}
