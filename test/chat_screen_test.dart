import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/chat_screen.dart';

void main() {
  testWidgets('ChatScreen displays message input', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('Sending message adds it to list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));

    await tester.enterText(find.byType(TextField), 'Test message');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('Test message'), findsOneWidget);
  });
}
