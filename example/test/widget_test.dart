import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_pdf_viewer_example/main.dart';

void main() {
  testWidgets('renders the example application shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    expect(find.text('PDFViewer'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
