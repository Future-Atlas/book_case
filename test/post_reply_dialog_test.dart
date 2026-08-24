import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/post_reply_dialog.dart';

void main() {
  testWidgets('locked reply dialog shows the limited-content message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPostReplyLockedDialog(context: context),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.text('返信は限定コンテンツです'), findsOneWidget);
  });

  testWidgets('reply dialog shows only the requested length guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPostReplyDialog(
              context: context,
              postId: 'post-id',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('100文字以内で返信できます'), findsOneWidget);
    expect(find.textContaining('URL'), findsNothing);
  });
}
