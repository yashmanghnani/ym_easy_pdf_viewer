import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ym_easy_pdf_viewer/ym_easy_pdf_viewer.dart';

void main() {
  const MethodChannel channel = MethodChannel('easy_pdf_viewer_plugin');
  TestWidgetsFlutterBinding.ensureInitialized();

  late File fixture;

  setUp(() async {
    fixture = File('${Directory.systemTemp.path}/ym_easy_pdf_viewer_test.pdf');
    await fixture.writeAsBytes(<int>[37, 80, 68, 70], flush: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          switch (call.method) {
            case 'getNumberOfPages':
              return 2;
            case 'getPage':
              return '/tmp/page-${call.arguments['pageNumber']}.png';
            case 'clearCacheDir':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() async {
    await fixture.delete();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('loads a document and caches pages', () async {
    final PDFDocument document = await PDFDocument.fromFile(fixture);

    expect(document.count, 2);
    expect(document.filePath, fixture.path);

    final PDFPage firstPage = await document.get();
    expect(firstPage.num, 1);
    expect(identical(firstPage, await document.get()), isTrue);
  });

  test('streams all pages in one-based order', () async {
    final PDFDocument document = await PDFDocument.fromFile(fixture);

    final List<PDFPage> pages = await document.getAll().toList();

    expect(pages.map((PDFPage page) => page.num), <int>[1, 2]);
  });

  test('rejects pages outside the document', () async {
    final PDFDocument document = await PDFDocument.fromFile(fixture);

    expect(document.get(page: 0), throwsRangeError);
    expect(document.get(page: 3), throwsRangeError);
  });
}
