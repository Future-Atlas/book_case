import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

Future<void> showPostReplyLockedDialog({
  required BuildContext context,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 64),
          SizedBox(height: 16),
          Text(
            '返信は限定コンテンツです',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

Future<bool> showPostReplyDialog({
  required BuildContext context,
  required String postId,
}) async {
  final controller = TextEditingController();
  var isSubmitting = false;

  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('返信する'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '100文字以内で返信できます',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              enabled: !isSubmitting,
              maxLength: 100,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '返信内容を入力',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: isSubmitting
                ? null
                : () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: isSubmitting
                ? null
                : () async {
                    setDialogState(() => isSubmitting = true);
                    final service = SupabaseService();
                    final error = await service.createPostReply(
                      postId: postId,
                      message: controller.text,
                    );
                    if (!dialogContext.mounted) return;
                    if (error == null) {
                      Navigator.of(dialogContext).pop(true);
                      return;
                    }
                    setDialogState(() => isSubmitting = false);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(error)),
                    );
                  },
            child: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('返信を投稿'),
          ),
        ],
      ),
    ),
  );

  controller.dispose();
  return submitted == true;
}
