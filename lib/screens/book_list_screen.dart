import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = BookListController();
    _controller.initialize(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showPostComposerDialog(Book book) async {
    double rating = 5.0;
    bool isSpoiler = false;
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFE9E9E9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              content: DefaultTextStyle.merge(
                style: const TextStyle(color: Color(0xFF1E1E1E)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 92,
                          height: 132,
                          color: Colors.grey[350],
                          child: book.coverUrl.trim().isNotEmpty
                              ? Image.network(
                                  book.coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildMissingCoverFallback(book),
                                )
                              : _buildMissingCoverFallback(book),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setDialogState(() => isSpoiler = false);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: isSpoiler
                                            ? Colors.white70
                                            : const Color(0xFFFF1F1F),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: const Text('ネタバレなし投稿'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setDialogState(() => isSpoiler = true);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: isSpoiler
                                            ? const Color(0xFFFF1F1F)
                                            : Colors.white70,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: const Text('ネタバレあり投稿'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  ...List.generate(5, (index) {
                                    final starVal = index + 1.0;
                                    return IconButton(
                                      icon: Icon(
                                        rating >= starVal
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: const Color(0xFFE0B400),
                                        size: 42,
                                      ),
                                      onPressed: () {
                                        setDialogState(() => rating = starVal);
                                      },
                                    );
                                  }),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 52 / 2,
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
                    const SizedBox(height: 10),
                    Container(
                      color: const Color(0xFFD2D2D2),
                      padding: const EdgeInsets.all(10),
                      child: TextField(
                        controller: commentController,
                        maxLines: 5,
                        style: const TextStyle(
                          color: Color(0xFF1E1E1E),
                          fontSize: 16,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          hintText: '感想を書いてください',
                          hintStyle: TextStyle(
                            color: Color(0xFF6A6A6A),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                    ),
                  ],
                ),
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
                    final comment = isSpoiler
                        ? '[ネタバレあり]\n${commentController.text.trim()}'
                        : '[ネタバレなし]\n${commentController.text.trim()}';

                    final success = await service.createPost(
                      bookId: book.id,
                      rating: rating,
                      comment: comment,
                    );

                    if (success && mounted) {
                      commentController.clear();
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
    commentController.dispose();
  }

  void _showBookDetailDialog(Book book) {
    showDialog(
      context: context,
      builder: (context) {
        final hasCover = book.coverUrl.trim().isNotEmpty;

        return Dialog(
          backgroundColor: const Color(0xFFE6E6E6),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Color(0xFF1E1E1E)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 560;

                        final coverBlock = SizedBox(
                          width: isNarrow ? double.infinity : 160,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: isNarrow ? double.infinity : 140,
                                height: 210,
                                color: Colors.grey[400],
                                child: hasCover
                                    ? Image.network(
                                        book.coverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return _buildMissingCoverFallback(
                                                book,
                                              );
                                            },
                                      )
                                    : _buildMissingCoverFallback(book),
                              ),
                              const SizedBox(height: 12),
                              if (!hasCover) ...[
                                Text(
                                  book.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  book.author,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );

                        final detailBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: 190,
                                height: 64,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _showPostComposerDialog(book);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: const Color(0xFFFF1F1F),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: const Text(
                                    '読了',
                                    style: TextStyle(
                                      fontSize: 52 / 2,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                ...List.generate(5, (index) {
                                  final isFilled =
                                      index < book.ratingAvg.floor();
                                  return Icon(
                                    isFilled ? Icons.star : Icons.star_border,
                                    color: const Color(0xFFE0B400),
                                    size: 42,
                                  );
                                }),
                                const SizedBox(width: 12),
                                Text(
                                  book.ratingAvg.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Color(0xFFE0B400),
                                    fontSize: 52 / 2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              color: const Color(0xFFD8D8D8),
                              child: Text(
                                book.description.trim().isNotEmpty
                                    ? book.description
                                    : 'あらすじ情報はまだ登録されていません。',
                                style: const TextStyle(
                                  color: Color(0xFF1E1E1E),
                                  fontSize: 20 / 2,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              coverBlock,
                              const SizedBox(height: 12),
                              detailBlock,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            coverBlock,
                            const SizedBox(width: 20),
                            Expanded(child: detailBlock),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMissingCoverFallback(Book book) {
    return Container(
      color: Colors.grey[300],
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book, size: 28, color: Colors.black54),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            book.author,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
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
                        _buildTopHeroImage(),
                        _buildHeader(),
                        _buildSearchBar(),
                        if (_controller.searchQuery.isNotEmpty)
                          _buildSearchResults()
                        else ...[
                          _buildGenreSection(
                            title: 'おすすめの本',
                            sectionCode: 'Section 3',
                            bookList: _controller.recommendedBooks,
                            onLoadMore: _controller.loadMoreRecommended,
                          ),
                          const AdBanner(sectionLabel: 'Section 2'),
                          _buildGenreSection(
                            title: '洋書',
                            sectionCode: 'Section 4',
                            bookList: _controller.westernBooks,
                            onLoadMore: _controller.loadMoreWestern,
                          ),
                          _buildGenreSection(
                            title: '人気作品',
                            sectionCode: 'Section 6',
                            bookList: _controller.popularBooks,
                            onLoadMore: _controller.loadMorePopular,
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

  Widget _buildTopHeroImage() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRect(
        child: Transform.translate(
          offset: const Offset(-16, 0),
          child: SizedBox(
            width: screenWidth,
            height: 170,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF090909)),
                ClipPath(
                  clipper: _DiagonalRedClipper(),
                  child: const ColoredBox(color: Color(0xFFFF1F1F)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Image.asset(
                    'assets/images/Sharemarium.png',
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text(
                          'Sharemarium',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildGenreSection({
    required String title,
    required String sectionCode,
    required List<Book> bookList,
    required VoidCallback onLoadMore,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title, sectionCode, failedToLoad: bookList.isEmpty),
        _buildBookCarousel(bookList, onLoadMore),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    String sectionCode, {
    bool failedToLoad = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
                if (failedToLoad) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '取得できませんでした',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFFF3B30),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
        height: 205,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFFF3B30),
              size: 22,
            ),
            const SizedBox(height: 8),
            Text(
              'データを取得できませんでした',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '楽天APIキー未設定、または通信エラーの可能性があります。',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
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
          return BookCard(book: book, onTap: () => _showBookDetailDialog(book));
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
                onTap: () => _showBookDetailDialog(book),
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
            '© 2026 Sharemarium. All rights reserved.',
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

class _DiagonalRedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.33, 0)
      ..lineTo(size.width * 0.47, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
