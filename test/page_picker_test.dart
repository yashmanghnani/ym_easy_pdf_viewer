import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ym_easy_pdf_viewer/src/page_picker.dart';

void main() {
  testWidgets('page picker renders and confirms under standalone Material', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<int>(
              context: context,
              builder: (_) => const PagePicker(
                title: 'Choose page',
                maxValue: 5,
                initialValue: 2,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Choose page'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Choose page'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
