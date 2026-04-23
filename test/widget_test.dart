import 'package:evsmart_plus/screens/app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EVSmart+ header renders title and search action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppHeader(onSearch: (_) {})),
      ),
    );

    expect(find.text('EVSmart+'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}
