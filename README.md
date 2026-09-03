# ym_easy_pdf_viewer

[![pub package](https://img.shields.io/pub/v/ym_easy_pdf_viewer.svg)](https://pub.dev/packages/ym_easy_pdf_viewer)

A Flutter PDF viewer for Android and iOS. PDFs can be loaded from bundled assets,
local files, or URLs and displayed with lazy page rendering, swipe navigation,
page picking, and pinch/double-tap zoom.

## Requirements

- Flutter 3.47.2 or newer
- Dart 3.13.2 or newer
- Android API 23 or newer
- iOS 15.0 or newer

No storage or network permissions are required by the plugin itself. URL loading
uses `flutter_cache_manager` and the platform renderers write temporary page
previews to the application's cache directory.

## Installation

```sh
flutter pub add ym_easy_pdf_viewer
```

Or add it to `pubspec.yaml`:

```yaml
dependencies:
  ym_easy_pdf_viewer: ^1.0.0
```

For pre-1.0 versions, update imports from
`package:ym_easy_pdf_viewer/easy_pdf_viewer.dart` to
`package:ym_easy_pdf_viewer/ym_easy_pdf_viewer.dart`.

## Loading a document

```dart
import 'dart:io';

import 'package:ym_easy_pdf_viewer/ym_easy_pdf_viewer.dart';

final PDFDocument fromAsset =
    await PDFDocument.fromAsset('assets/sample.pdf');

final PDFDocument fromFile =
    await PDFDocument.fromFile(File('/path/to/document.pdf'));

final PDFDocument fromUrl = await PDFDocument.fromURL(
  'https://example.com/document.pdf',
  headers: <String, String>{'Authorization': 'Bearer token'},
);
```

Register assets in the application `pubspec.yaml` before calling
`PDFDocument.fromAsset`:

```yaml
flutter:
  assets:
    - assets/sample.pdf
```

## Displaying the built-in viewer

```dart
class PdfScreen extends StatelessWidget {
  const PdfScreen({required this.document, super.key});

  final PDFDocument document;

  @override
  Widget build(BuildContext context) {
    return PDFViewer(
      document: document,
      lazyLoad: true,
      showNavigation: true,
      showPicker: true,
      scrollDirection: Axis.horizontal,
    );
  }
}
```

Use `lazyLoad: false` only when the document is small and all pages should be
rendered before the viewer becomes interactive. For larger documents, the
default lazy mode keeps memory and startup time lower.

## Rendering individual pages

```dart
final PDFPage page = await document.get(page: 1);

await for (final PDFPage page in document.getAll()) {
  // Add each page to a custom layout.
}
```

Page numbers are one-based. `PDFDocument.get` throws a `RangeError` when the
requested page is outside the document.

## Download progress

```dart
import 'dart:async';

late final StreamSubscription<FileResponse> subscription;

subscription = PDFDocument.fromURLWithDownloadProgress(
  'https://example.com/document.pdf',
  downloadProgress: (DownloadProgress progress) {
    final int downloadedBytes = progress.downloaded ?? 0;
    // Update the progress UI.
  },
  onDownloadComplete: (PDFDocument document) {
    // Display the downloaded document.
  },
);

// Cancel from dispose() if the screen is removed before completion.
subscription.cancel();
```

## Cache management

Rendered previews are cleared automatically when a document is loaded unless
`clearPreviewCache: false` is provided. You can clear them explicitly:

```dart
await PDFDocument.clearPreviewCache();
```

Downloaded source files remain managed by the supplied `CacheManager`.

## Viewer customization

`PDFViewer` supports custom indicator and navigation builders, custom tooltips,
background and button colors, vertical or horizontal paging, zoom limits,
custom progress widgets, an external `PageController`, and an
`onPageChanged` callback. See the Dart API documentation for the complete
option list.

## Development

```sh
flutter pub get
flutter analyze
flutter test
flutter pub publish --dry-run
```

The `example` directory demonstrates asset, URL, and download-progress
loading. Android builds use the Flutter Plugin DSL, Android Gradle Plugin 9.1,
Gradle 9.3.1, and Java 17.

## License

This project is distributed under the license in [LICENSE](LICENSE).
