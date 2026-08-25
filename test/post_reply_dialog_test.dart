import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharemarium/services/input_security_service.dart';
import 'package:sharemarium/widgets/post_reply_dialog.dart';

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
            onPressed: () =>
                showPostReplyDialog(context: context, postId: 'post-id'),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('100文字以内で返信できます'), findsOneWidget);
    expect(find.textContaining('URL'), findsNothing);

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.minLines, 5);
    expect(textField.maxLines, 5);

    final initialWidth = tester.getSize(find.byType(TextField)).width;
    await tester.enterText(
      find.byType(TextField),
      List.filled(100, 'あ').join(),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(TextField)).width, initialWidth);
  });

  test('reply character count excludes spaces and line breaks', () {
    expect(InputSecurityService.replyCharacterCount('あ い\nう'), 3);
    expect(InputSecurityService.validateReplyMessage('あ い\nう'), isNull);

    final oneHundredCharacters = List.filled(100, 'あ').join();
    expect(
      InputSecurityService.validateReplyMessage('$oneHundredCharacters\n   '),
      isNull,
    );
    expect(
      InputSecurityService.validateReplyMessage('$oneHundredCharactersあ'),
      '返信は100文字以内で入力してください。',
    );
  });
}
