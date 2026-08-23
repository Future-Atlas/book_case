import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

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
              '100文字以内。URL・電話番号・住所・画像動画に関する記述は投稿できません。',
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