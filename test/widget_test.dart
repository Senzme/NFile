import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nfile/main.dart';
import 'package:nfile/providers/file_manager_provider.dart';
import 'package:nfile/providers/media_provider.dart';

void main() {
  testWidgets('NFileApp initialization smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FileManagerProvider()),
          ChangeNotifierProvider(create: (_) => MediaProvider()),
        ],
        child: const NFileApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
