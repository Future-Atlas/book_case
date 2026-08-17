import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/book_card.dart';
import '../widgets/ad_banner.dart';
import '../widgets/post_card.dart';
import '../controllers/book_list_controller.dart';
import '../models/book.dart';
import '../models/post.dart';
import '../models/social_models.dart';
import '../services/supabase_service.dart';
import '../widgets/post_composer_dialog.dart';
import 'report_post_dialog.dart';
import 'user_profile_screen.dart';

class BookListScreen extends StatefulWidget {
  const BookListScreen({super.key});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  late final BookListController _controller;
  final ScrollController _timelineScrollController = ScrollController();
  final Set<String> _pendingReactionPostIds = <String>{};

  @override
  void initState() {
    super.initState();
    _controller = BookListController();
    _controller.initialize(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    _timelineScrollController.dispose();
    super.dispose();
  }

  Future<void> _showPostComposerDialog(Book book) async {
    final posted = await showPostComposerDialog(context: context, book: book);
    if (posted && mounted) {
      _controller.loadData(context);
    }
  }

  Future<void> _editPost(Post post) async {
    final book = Book(
      id: post.bookId,
      title: post.bookTitle,
      author: post.bookAuthor,
      publisher: '',
      pubDate: '',
      isbn: post.bookId,
      coverUrl: post.bookCoverUrl,
    );
    final edited = await showPostComposerDialog(
      context: context,
      book: book,
      existingPost: post,
    );
    if (edited && mounted) await _controller.loadData(context);
  }

  Future<bool> _ensureAuthenticated() async {
    final service = Provider.of<SupabaseService>(context, listen: false);
    if (service.isAuthenticated) return true;
    final result = await Navigator.of(context).pushNamed('/login');
    return mounted && (result == true || service.isAuthenticated);
  }

  Future<void> _openUserProfile(String profileId) async {
    if (!await _ensureAuthenticated() || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          profileId: profileId,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (mounted) await _controller.loadData(context);
  }

  Future<void> _toggleReaction(String postId, PostReactionType reaction) async {
    if (!await _ensureAuthenticated() || !mounted) return;
    if (!_pendingReactionPostIds.add(postId)) return;

    final previous = _controller.toggleTimelineReactionOptimistically(
      postId,
      reaction,
    );
    final service = Provider.of<SupabaseService>(context, listen: false);
    final success = await service.setPostReaction(postId, reaction);
    _pendingReactionPostIds.remove(postId);
    if (!mounted) return;

    if (!success && previous != null) {
      _controller.restoreTimelinePost(previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('リアクションを更新できませんでした。')));
    }
  }

  Future<void> _reportPost(String postId) async {
    if (!await _ensureAuthenticated() || !mounted) return;
    await showPostReportDialog(context: context, postId: postId);
  }

  void _showFavoriteResult(FavoriteToggleResult result) {
    final message = switch (result) {
      FavoriteToggleResult.added => 'お気に入りに登録しました。',
      FavoriteToggleResult.removed => 'お気に入りから解除しました。',
      FavoriteToggleResult.limitReached => 'もうこれ以上は登録できません。登録済みの本と入れ替えてください。',
      FavoriteToggleResult.requiresRead => '読了（投稿）した本のみお気に入りに追加できます。',
      FavoriteToggleResult.failed => 'お気に入りを更新できませんでした。',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleFavoriteFromPost(Post post) async {
    final service = Provider.of<SupabaseService>(context, listen: false);
    final result = await service.toggleFavorite(post.bookId);
    if (!mounted) return;
    _showFavoriteResult(result);
  }

  Future<void> _deletePost(Post post) async {
    final service = Provider.of<SupabaseService>(context, listen: false);
    if (post.profileId != service.activeProfileId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('投稿を削除しますか？'),
        content: Text(
          '「${post.bookTitle}」の投稿を削除します。\n'
          'この本への投稿がほかにない場合、My 本棚からも削除されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final deleted = await service.deleteOwnPost(post.id);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿を削除できませんでした。')));
      return;
    }
    await _controller.loadData(context);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('投稿を削除しました。')));
  }

  void _showBookDetailDialog(Book book) {
    showDialog(
      context: context,
      builder: (context) {
        final hasCover = book.coverUrl.trim().isNotEmpty;
        final service = Provider.of<SupabaseService>(context, listen: false);
        final isReadFuture = service.isBookReadByCurrentUser(bookId: book.id);
        final isFavoriteFuture = service.isBookFavoritedByCurrentUser(book.id);

        return Dialog(
          backgroundColor: const Color(0xFFE6E6E6),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
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
                          width: isNarrow ? double.infinity : 220,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: isNarrow ? double.infinity : 200,
                                height: isNarrow ? 240 : 300,
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
                            FutureBuilder<bool>(
                              future: isReadFuture,
                              builder: (context, snapshot) {
                                final isRead = snapshot.data ?? false;
                                final isChecking =
                                    snapshot.connectionState ==
                                    ConnectionState.waiting;
                                return Align(
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: 190,
                                    height: 64,
                                    child: ElevatedButton(
                                      onPressed: isRead || isChecking
                                          ? null
                                          : () async {
                                              if (!mounted) return;
                                              Navigator.of(this.context).pop();
                                              _showPostComposerDialog(book);
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: const Color(
                                          0xFFFF1F1F,
                                        ),
                                        disabledBackgroundColor: Colors.black,
                                        disabledForegroundColor: isRead
                                            ? const Color(0xFF00BFFF)
                                            : Colors.grey,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
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
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            FutureBuilder<bool>(
                              future: isFavoriteFuture,
                              builder: (context, snapshot) {
                                final isFavorite = snapshot.data ?? false;
                                final isLoading =
                                    snapshot.connectionState ==
                                    ConnectionState.waiting;
                                return Align(
                                  alignment: Alignment.center,
                                  child: OutlinedButton.icon(
                                    onPressed: isLoading
                                        ? null
                                        : () async {
                                            if (!service.isAuthenticated) {
                                              Navigator.of(context).pop();
                                              final authenticated =
                                                  await _ensureAuthenticated();
                                              if (authenticated && mounted) {
                                                _showBookDetailDialog(book);
                                              }
                                              return;
                                            }

                                            final result = await service
                                                .toggleFavorite(book.id);
                                            if (!mounted) return;
                                            if (context.mounted &&
                                                (result ==
                                                        FavoriteToggleResult
                                                            .added ||
                                                    result ==
                                                        FavoriteToggleResult
                                                            .removed)) {
                                              Navigator.of(context).pop();
                                            }
                                            _showFavoriteResult(result);
                                          },
                                    icon: Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: const Color(0xFFD00303),
                                    ),
                                    label: Text(
                                      isFavorite ? 'お気に入り解除' : 'お気に入りに登録',
                                    ),
                                  ),
                                );
                              },
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
                              child: SizedBox(
                                height: isNarrow ? 170 : 230,
                                child: Scrollbar(
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    child: Text(
                                      book.description.trim().isNotEmpty
                                          ? book.description
                                          : 'あらすじ情報はまだ登録されていません。',
                                      style: const TextStyle(
                                        color: Color(0xFF1E1E1E),
                                        fontSize: 26 / 2,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
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
                          crossAxisAlignment: CrossAxisAlignment.center,
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
            color: const Color(0xFFD00303),
            child: _controller.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD00303)),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopHeroImage(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSearchBar(),
                              if (_controller.searchQuery.isNotEmpty)
                                _buildSearchResults()
                              else ...[
                                _buildGenreSection(
                                  title: 'おすすめの本',
                                  bookList: _controller.recommendedBooks,
                                  onLoadMore: _controller.loadMoreRecommended,
                                  onLoadPrevious:
                                      _controller.loadPreviousRecommended,
                                  canLoadPrevious:
                                      _controller.canLoadPreviousRecommended,
                                  isLoadingMore:
                                      _controller.isLoadingMoreRecommended,
                                  hasMore: _controller.hasMoreRecommended,
                                ),
                                const AdBanner(),
                                _buildGenreSection(
                                  title: '洋書',
                                  bookList: _controller.westernBooks,
                                  onLoadMore: _controller.loadMoreWestern,
                                  onLoadPrevious:
                                      _controller.loadPreviousWestern,
                                  canLoadPrevious:
                                      _controller.canLoadPreviousWestern,
                                  isLoadingMore:
                                      _controller.isLoadingMoreWestern,
                                  hasMore: _controller.hasMoreWestern,
                                ),
                                _buildGenreSection(
                                  title: '人気作品',
                                  bookList: _controller.popularBooks,
                                  onLoadMore: _controller.loadMorePopular,
                                  onLoadPrevious:
                                      _controller.loadPreviousPopular,
                                  canLoadPrevious:
                                      _controller.canLoadPreviousPopular,
                                  isLoadingMore:
                                      _controller.isLoadingMorePopular,
                                  hasMore: _controller.hasMorePopular,
                                ),
                                const AdBanner(),
                                _buildSectionHeader('タイムライン'),
                                _buildTimeline(),
                              ],
                              _buildFooter(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTopHeroImage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        height: 140.5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF090909)),
            ClipPath(
              clipper: _DiagonalRedClipper(),
              child: const ColoredBox(color: Color.fromARGB(255, 208, 3, 3)),
            ),
            Image.asset(
              'assets/images/Sharemarium.png',
              fit: BoxFit.fill,
              alignment: Alignment.centerLeft,
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
          ],
        ),
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
        border: Border.all(color: const Color(0xFF009D5B), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
          prefixIcon: const Icon(Icons.search, color: Color(0xFFD00303)),
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
    required List<Book> bookList,
    required Future<void> Function() onLoadMore,
    required VoidCallback onLoadPrevious,
    required bool canLoadPrevious,
    required bool isLoadingMore,
    required bool hasMore,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title, failedToLoad: bookList.isEmpty),
        _buildBookCarousel(
          bookList,
          onLoadMore: onLoadMore,
          onLoadPrevious: onLoadPrevious,
          canLoadPrevious: canLoadPrevious,
          isLoadingMore: isLoadingMore,
          hasMore: hasMore,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {bool failedToLoad = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
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
          if (failedToLoad) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD00303).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '取得できませんでした',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFD00303),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookCarousel(
    List<Book> bookList, {
    required Future<void> Function() onLoadMore,
    required VoidCallback onLoadPrevious,
    required bool canLoadPrevious,
    required bool isLoadingMore,
    required bool hasMore,
  }) {
    if (bookList.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD00303).withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFD00303),
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

    // Page controls live outside the horizontal list so they remain visible
    // even when the nine cards fill (or overflow) the available width.
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (canLoadPrevious)
            _buildCarouselPageButton(
              direction: AxisDirection.left,
              tooltip: '前の9冊に戻る',
              onPressed: onLoadPrevious,
            ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(),
              itemCount: bookList.length,
              itemBuilder: (context, index) => BookCard(
                book: bookList[index],
                marginRight: index == bookList.length - 1 ? 0 : 12,
                onTap: () => _showBookDetailDialog(bookList[index]),
              ),
            ),
          ),
          if (hasMore || isLoadingMore)
            _buildCarouselPageButton(
              direction: AxisDirection.right,
              tooltip: '次の9冊を読み込む',
              isLoading: isLoadingMore,
              onPressed: isLoadingMore ? null : () => onLoadMore(),
            ),
        ],
      ),
    );
  }

  Widget _buildCarouselPageButton({
    required AxisDirection direction,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: 28,
      child: Center(
        child: Tooltip(
          message: tooltip,
          child: InkResponse(
            onTap: onPressed,
            radius: 28,
            child: SizedBox(
              width: 28,
              height: 72,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFD00303),
                        ),
                      )
                    : CustomPaint(
                        size: const Size(22, 42),
                        painter: _CarouselTrianglePainter(direction),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = _controller.visibleSearchResults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            _controller.isSearching
                ? '検索中... (${results.length}件表示)'
                : '検索結果 (${results.length}件表示)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (_controller.isSearching)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (results.isEmpty)
          Container(
            height: 200,
            alignment: Alignment.center,
            child: Text(
              _controller.isSearching ? '検索しています...' : 'お探しの作品が見つかりませんでした。',
              style: TextStyle(color: Colors.grey[500]),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columnCount = width >= 900
                      ? 5
                      : width >= 680
                      ? 4
                      : width >= 460
                      ? 3
                      : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    clipBehavior: Clip.none,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnCount,
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
                  );
                },
              ),
              if (!_controller.isSearching &&
                  _controller.canLoadMoreSearchResults)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Align(
                    alignment: Alignment.center,
                    child: OutlinedButton.icon(
                      onPressed: _controller.loadMoreSearchResults,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('さらに読み込む'),
                    ),
                  ),
                ),
            ],
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

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final timelineHeight = (MediaQuery.sizeOf(context).height * 0.58)
        .clamp(420.0, 600.0)
        .toDouble();

    return Container(
      height: timelineHeight,
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.45)
              : Colors.black,
          width: 1.5,
        ),
      ),
      child: Scrollbar(
        controller: _timelineScrollController,
        thumbVisibility: true,
        child: ListView.builder(
          controller: _timelineScrollController,
          padding: const EdgeInsets.only(right: 8),
          physics: const ClampingScrollPhysics(),
          itemCount: _controller.timelinePosts.length,
          itemBuilder: (context, index) {
            final post = _controller.timelinePosts[index];
            final currentProfileId = Provider.of<SupabaseService>(
              context,
              listen: false,
            ).activeProfileId;
            return PostCard(
              key: ValueKey(post.id),
              post: post,
              concealSpoiler: post.profileId != currentProfileId,
              onUserTap: () => _openUserProfile(post.profileId),
              onReaction: post.profileId == currentProfileId
                  ? null
                  : (reaction) => _toggleReaction(post.id, reaction),
              onDelete: post.profileId == currentProfileId
                  ? () => _deletePost(post)
                  : null,
              onEdit: post.profileId == currentProfileId
                  ? () => _editPost(post)
                  : null,
              onFavorite: post.profileId == currentProfileId
                  ? () => _toggleFavoriteFromPost(post)
                  : null,
              onReport: post.profileId == currentProfileId
                  ? null
                  : () => _reportPost(post.id),
            );
          },
        ),
      ),
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

class _CarouselTrianglePainter extends CustomPainter {
  const _CarouselTrianglePainter(this.direction);

  final AxisDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (direction == AxisDirection.left) {
      canvas
        ..save()
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }

    const radius = 3.5;
    final path = Path();
    path
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, size.height / 2 - radius)
      ..quadraticBezierTo(
        size.width,
        size.height / 2,
        size.width - radius,
        size.height / 2 + radius,
      )
      ..lineTo(radius, size.height - radius)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFD00303));
    if (direction == AxisDirection.left) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CarouselTrianglePainter oldDelegate) =>
      oldDelegate.direction != direction;
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
