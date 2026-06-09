import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../widgets/book_card.dart';
import '../widgets/ad_banner.dart';
import '../widgets/post_card.dart';
import '../controllers/book_list_controller.dart';
import '../models/book.dart';

class BookListScreen extends StatefulWidget {
  final VoidCallback onNavigateToProfile;

  const BookListScreen({super.key, required this.onNavigateToProfile});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  late final BookListController _controller;
  final TextEditingController commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = BookListController();
    _controller.initialize(context);
  }

  @override
  void dispose() {
    commentController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showAddReviewDialog(Book book) {
    double rating = 5.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                '『${book.title}』のレビューを投稿',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '評価点数:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starVal = index + 1.0;
                      return IconButton(
                        icon: Icon(
                          rating >= starVal ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() => rating = starVal);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'コメント:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '読んだ感想を入力してください...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text(
                    'キャンセル',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '投稿する',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    if (commentController.text.trim().isEmpty) return;

                    final service = Provider.of<SupabaseService>(
                      context,
                      listen: false,
                    );
                    final success = await service.createPost(
                      bookId: book.id,
                      rating: rating,
                      comment: commentController.text.trim(),
                    );

                    if (success && mounted) {
                      commentController.clear(); // 💡 投稿成功時にテキストをクリア
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('レビューを投稿しました')),
                      );
                      _controller.loadData(context);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          color: Theme.of(context).scaffoldBackgroundColor,
          child: RefreshIndicator(
            onRefresh: () => _controller.loadData(context),
            color: const Color(0xFFFF3B30),
            child: _controller.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF3B30)),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        _buildSearchBar(),
                        if (_controller.searchQuery.isNotEmpty)
                          _buildSearchResults()
                        else ...[
                          _buildSectionHeader('おすすめの本', 'Section 3'),
                          _buildBookCarousel(
                            _controller.recommendedBooks,
                            _controller.loadMoreRecommended,
                          ),
                          const AdBanner(sectionLabel: 'Section 2'),
                          _buildSectionHeader('洋書', 'Section 4'),
                          _buildBookCarousel(
                            _controller
                                .westernBooks, // 💡 ここで400エラーが起きても「本がありません」として安全に処理
                            _controller.loadMoreWestern,
                          ),
                          _buildSectionHeader('人気作品', 'Section 6'),
                          _buildBookCarousel(
                            _controller.popularBooks,
                            _controller.loadMorePopular,
                          ),
                          const AdBanner(sectionLabel: 'Section 5'),
                          _buildSectionHeader('タイムライン', 'Section 5'),
                          _buildTimeline(),
                        ],
                        _buildFooter(),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'BookCase',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: widget.onNavigateToProfile,
            icon: const Icon(
              Icons.person_outline,
              size: 18,
              color: Colors.white,
            ),
            label: const Text(
              'プロフィール',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 50,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller.searchController,
        decoration: InputDecoration(
          hintText: '本を検索 (作品名、著者、ジャンル)...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFFF3B30)),
          suffixIcon: _controller.searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _controller.searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String sectionCode) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sectionCode,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () {},
            child: const Icon(Icons.chevron_right, color: Color(0xFFFF3B30)),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCarousel(List<Book> bookList, VoidCallback onLoadMore) {
    if (bookList.isEmpty) {
      return Container(
        height: 205, // カルーセルの一致する高さ
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'データを読み込めませんでした、または作品がありません。',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      );
    }

    final scrollController = ScrollController();
    bool isTriggered = false;

    scrollController.addListener(() {
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentScroll = scrollController.position.pixels;

      if (currentScroll >= maxScroll - 100) {
        if (!isTriggered) {
          isTriggered = true;
          onLoadMore();
        }
      } else {
        if (currentScroll < maxScroll - 150) {
          isTriggered = false;
        }
      }
    });

    return SizedBox(
      height: 205,
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: bookList.length,
        itemBuilder: (context, index) {
          final book = bookList[index];
          return BookCard(book: book, onTap: () => _showAddReviewDialog(book));
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    final lowerQuery = _controller.searchQuery.toLowerCase();
    final results = _controller.books
        .where(
          (book) =>
              book.title.toLowerCase().contains(lowerQuery) ||
              book.author.toLowerCase().contains(lowerQuery) ||
              book.genre.toLowerCase().contains(lowerQuery),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '検索結果 (${results.length}件)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (results.isEmpty)
          Container(
            height: 200,
            alignment: Alignment.center,
            child: Text(
              'お探しの作品が見つかりませんでした。',
              style: TextStyle(color: Colors.grey[500]),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final book = results[index];
              return BookCard(
                book: book,
                width: double.infinity,
                onTap: () => _showAddReviewDialog(book),
              );
            },
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildTimeline() {
    if (_controller.timelinePosts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Text(
          'タイムラインの投稿がありません。',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _controller.timelinePosts.length,
      itemBuilder: (context, index) {
        return PostCard(post: _controller.timelinePosts[index]);
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.only(top: 40, bottom: 30),
      alignment: Alignment.center,
      child: Column(
        children: [
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            '© 2026 BookCase. All rights reserved.',
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'Powered by Supabase & PostgreSQL',
            style: TextStyle(color: Colors.grey[400], fontSize: 9),
          ),
        ],
      ),
    );
  }
}
