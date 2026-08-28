import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/moderation_models.dart';
import '../services/supabase_service.dart';

Future<void> showPostReportDialog({
  required BuildContext context,
  required String postId,
}) => _showReportDialog(
  context: context,
  title: '投稿を報告',
  submit: (service, category, details) => service.submitPostReport(
    postId: postId,
    category: category,
    details: details,
  ),
);

Future<void> showReplyReportDialog({
  required BuildContext context,
  required String replyId,
}) => _showReportDialog(
  context: context,
  title: '返信を報告',
  submit: (service, category, details) => service.submitReplyReport(
    replyId: replyId,
    category: category,
    details: details,
  ),
);

Future<void> _showReportDialog({
  required BuildContext context,
  required String title,
  required Future<bool> Function(
    SupabaseService service,
    ReportCategory category,
    String details,
  )
  submit,
}) async {
  var selected = ReportCategory.spam;
  final detailsController = TextEditingController();
  var submitting = false;

  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('報告理由を選択してください。'),
              const SizedBox(height: 8),
              RadioGroup<ReportCategory>(
                groupValue: selected,
                onChanged: (value) {
                  if (!submitting && value != null) {
                    setDialogState(() => selected = value);
                  }
                },
                child: Column(
                  children: [
                    for (final category in ReportCategory.values)
                      RadioListTile<ReportCategory>(
                        value: category,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        enabled: !submitting,
                        title: Text(category.label),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: detailsController,
                enabled: !submitting,
                maxLength: 1000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '詳細（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: submitting
                ? null
                : () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: submitting
                ? null
                : () async {
                    setDialogState(() => submitting = true);
                    final service = Provider.of<SupabaseService>(
                      dialogContext,
                      listen: false,
                    );
                    final success = await submit(
                      service,
                      selected,
                      detailsController.text,
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop(success);
                  },
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('報告を送信'),
          ),
        ],
      ),
    ),
  );
  detailsController.dispose();

  if (!context.mounted || submitted == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        submitted ? '報告を送信しました。内容を確認します。' : '報告を送信できませんでした。しばらくしてから再試行してください。',
      ),
    ),
  );
}
