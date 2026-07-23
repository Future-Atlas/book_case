import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/supabase_service.dart';

Future<bool> showPostComposerDialog({
  required BuildContext context,
  required Book book,
}) async {
  double rating = 5.0;
  bool isSpoiler = false;
  bool isSubmitting = false;
  final commentController = TextEditingController();

  final posted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFE9E9E9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 88,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 88,
                                height: 126,
                                color: Colors.grey[350],
                                child: book.coverUrl.trim().isNotEmpty
                                    ? Image.network(
                                        book.coverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _MissingCover(book: book),
                                      )
                                    : _MissingCover(book: book),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                book.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _SpoilerButton(
                                    label: 'ネタバレなし投稿',
                                    selected: !isSpoiler,
                                    onPressed: () {
                                      setDialogState(() => isSpoiler = false);
                                    },
                                  ),
                                  _SpoilerButton(
                                    label: 'ネタバレあり投稿',
                                    selected: isSpoiler,
                                    onPressed: () {
                                      setDialogState(() => isSpoiler = true);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 2,
                                children: [
                                  ...List.generate(5, (index) {
                                    final starValue = index + 1.0;
                                    return IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 34,
                                        minHeight: 40,
                                      ),
                                      icon: Icon(
                                        rating >= starValue
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: const Color(0xFFE0B400),
                                        size: 34,
                                      ),
                                      onPressed: () {
                                        setDialogState(
                                          () => rating = starValue,
                                        );
                                      },
                                    );
                                  }),
                                  const SizedBox(width: 6),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Color(0xFFE0B400),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      color: const Color(0xFFD2D2D2),
                      padding: const EdgeInsets.all(10),
                      child: TextField(
                        controller: commentController,
                        maxLines: 5,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          hintText: '感想を書いてください',
                          hintStyle: TextStyle(color: Colors.black54),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: Text('キャンセル', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final review = commentController.text.trim();
                        if (review.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('感想を入力してください')),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        final service = Provider.of<SupabaseService>(
                          context,
                          listen: false,
                        );
                        final comment = isSpoiler
                            ? '[ネタバレあり]\n$review'
                            : '[ネタバレなし]\n$review';
                        final success = await service.createPost(
                          bookId: book.id,
                          rating: rating,
                          comment: comment,
                        );

                        if (!dialogContext.mounted) return;
                        if (success) {
                          Navigator.of(dialogContext).pop(true);
                        } else {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('投稿できませんでした。もう一度お試しください。'),
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('投稿する'),
              ),
            ],
          );
        },
      );
    },
  );

  commentController.dispose();
  if (posted == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('レビューを投稿しました')));
  }
  return posted ?? false;
}

class _SpoilerButton extends StatelessWidget {
  const _SpoilerButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: selected ? const Color(0xFFFF1F1F) : Colors.white70,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label),
    );
  }
}

class _MissingCover extends StatelessWidget {
  const _MissingCover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[300],
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, color: Colors.black45, size: 30),
          const SizedBox(height: 6),
          Text(
            book.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
