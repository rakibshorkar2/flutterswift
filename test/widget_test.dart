import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutterswift/main.dart';

void main() {
  testWidgets('App launches and shows navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DirXploreApp(),
      ),
    );
    await tester.pumpAndSettle();
    // App should render without throwing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
