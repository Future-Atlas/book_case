import 'package:flutter/material.dart';
import '../models/post.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final bool showUserInfo;

  const PostCard({super.key, required this.post, this.showUserInfo = true});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryTextColor = colorScheme.onSurface;
    final secondaryTextColor = colorScheme.onSurface.withOpacity(0.72);
    final tertiaryTextColor = colorScheme.onSurface.withOpacity(0.58);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header (for Home Timeline)
            if (showUserInfo) ...[
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: post.userAvatarUrl.isNotEmpty
                        ? NetworkImage(post.userAvatarUrl)
                        : null,
                    radius: 18,
                    child: post.userAvatarUrl.isEmpty
                        ? const Icon(Icons.person, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.username,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: primaryTextColor,
                        ),
                      ),
                      Text(
                        _formatDate(post.createdAt),
                        style: TextStyle(
                          color: tertiaryTextColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 0.8),
            ],

            // Book & Comment Body
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post.bookCoverUrl,
                    width: 70,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 70,
                      height: 100,
                      color: Colors.grey[300],
                      child: const Icon(Icons.book, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Review Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Book Title / Author
                      Text(
                        post.bookTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        post.bookAuthor,
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Rating Stars
                      Row(
                        children: [
                          _buildStars(post.rating),
                          const SizedBox(width: 8),
                          Text(
                            '${post.rating.toStringAsFixed(1)} / 5.0',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // User Comment
                      Text(
                        post.comment,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),

                      // Date if not showing user info (like in user profile tab)
                      if (!showUserInfo) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            _formatDate(post.createdAt),
                            style: TextStyle(
                              color: tertiaryTextColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStars(double rating) {
    List<Widget> stars = [];
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;

    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(const Icon(Icons.star, color: Colors.amber, size: 14));
      } else if (i == fullStars && hasHalfStar) {
        stars.add(const Icon(Icons.star_half, color: Colors.amber, size: 14));
      } else {
        stars.add(Icon(Icons.star_border, color: Colors.grey[400], size: 14));
      }
    }
    return Row(children: stars);
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
