import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/book.dart';
import '../models/user_profile.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../widgets/book_card.dart';
import '../repositories/book_repository.dart';

class UserProfileScreen extends StatefulWidget {
  final VoidCallback onBack;
  final bool showAppBar;

  const UserProfileScreen({
    super.key,
    required this.onBack,
    this.showAppBar = true,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _footerSearchController = TextEditingController();
  final BookRepository _bookRepository = BookRepository();
  UserProfile? _profile;
  List<Post> _userPosts = [];
  List<Book> _collections = [];
  List<Book> _favorites = [];
  List<Book> _searchResults = [];
  bool _isLoading = true;
  bool _isSearchPanelOpen = false;
  bool _isSearchingBooks = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _footerSearchController.dispose();
    super.dispose();
  }

  void _toggleSearchPanel() {
    setState(() {
      _isSearchPanelOpen = !_isSearchPanelOpen;
      if (!_isSearchPanelOpen) {
        _footerSearchController.clear();
        _searchResults = [];
        _searchError = null;
        _isSearchingBooks = false;
      }
    });
  }

  Future<void> _searchBooksFromFooter(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearchingBooks = true;
      _searchError = null;
    });

    try {
      final books = await _bookRepository.searchBooks(keyword);
      if (!mounted) return;
      setState(() {
        _searchResults = books;
        _searchError = books.isEmpty ? '該当する本が見つかりませんでした。' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchError = '検索に失敗しました。しばらくしてから再試行してください。';
        _searchResults = [];
      });
    } finally {
      if (mounted) {
        setState(() => _isSearchingBooks = false);
      }
    }
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final service = Provider.of<SupabaseService>(context, listen: false);
    final uid = service.activeProfileId;

    if (uid.isEmpty) {
      if (mounted) {
        setState(() {
          _profile = null;
          _userPosts = [];
          _collections = [];
          _favorites = [];
          _isLoading = false;
        });
      }
      return;
    }

    final profile = await service.fetchUserProfile(uid);
    final posts = await service.fetchUserPosts(uid);
    final colls = await service.fetchUserCollections(uid);
    final favs = await service.fetchUserFavorites(uid);

    if (mounted) {
      setState(() {
        _profile = profile;
        _userPosts = posts;
        _collections = colls;
        _favorites = favs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: widget.onBack,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.black87),
                  onPressed: () async {
                    final service = Provider.of<SupabaseService>(
                      context,
                      listen: false,
                    );
                    await service.signOut();
                    if (!mounted) return;
                    widget.onBack();
                  },
                ),
              ],
              title: const Text(
                'マイプロフィール',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              centerTitle: true,
            )
          : null,
      bottomNavigationBar: _buildFooterSearchPanel(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF3B30)),
            )
          : _profile == null
          ? const Center(child: Text('プロフィールの読み込みに失敗しました。')) // ⭕ データ未取得時の安全ガード
          : Container(
              width: double.infinity,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  // Profile Header Card
                  _buildProfileHeader(),

                  const SizedBox(height: 16),

                  // Custom Tab Bar with premium design
                  _buildTabBar(),

                  // Tab View Contents
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPostsTab(),
                        _buildGridTab(
                          _collections,
                          'コレクションはありません。',
                          showDescription: true,
                        ),
                        _buildGridTab(_favorites, 'お気に入りの本はありません。'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    if (_profile == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Row containing avatar, username, ID, and stat fields
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Photo
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _profile!.avatarUrl.isNotEmpty
                      ? NetworkImage(_profile!.avatarUrl)
                      : null,
                  child: _profile!.avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(width: 16),

                // Name and Stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username
                      Text(
                        _profile!.username,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // ⭕ 文字数が足りない場合の RangeError 回避
                      Text(
                        _profile!.id.length >= 8
                            ? '@${_profile!.id.substring(0, 8)}'
                            : '@${_profile!.id}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Stat counters row
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn(
                              '読了',
                              _profile!.readCount.toString(),
                            ),
                            _buildStatColumn(
                              'フォロワー',
                              _profile!.followersCount.toString(),
                            ),
                            _buildStatColumn(
                              'フォロー',
                              _profile!.followingCount.toString(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bio comment box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '自己紹介',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _profile!.bio.isNotEmpty
                        ? _profile!.bio
                        : '自己紹介はまだ登録されていません。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[850],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: '投稿'),
          Tab(text: 'コレクション'),
          Tab(text: 'お気に入り'),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    if (_userPosts.isEmpty) {
      return _buildEmptyState('投稿したレビューはありません。');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        // Hide user info header since profile context is clear
        return PostCard(post: _userPosts[index], showUserInfo: false);
      },
    );
  }

  Widget _buildGridTab(
    List<Book> booksList,
    String emptyMessage, {
    bool showDescription = false,
  }) {
    if (booksList.isEmpty) {
      return _buildEmptyState(emptyMessage);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: booksList.length,
      itemBuilder: (context, index) {
        final book = booksList[index];
        return BookCard(
          book: book,
          width: double.infinity,
          height: 140,
          coverHeightRatio: showDescription ? (2 / 3) : (1 / 3),
          showDescription: showDescription,
          descriptionMaxLines: 3,
        );
      },
    );
  }

  Widget _buildFooterSearchPanel() {
    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: _isSearchPanelOpen ? 310 : 74,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: _isSearchPanelOpen
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _footerSearchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _searchBooksFromFooter,
                          decoration: InputDecoration(
                            hintText: '検索',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '検索',
                        onPressed: () => _searchBooksFromFooter(
                          _footerSearchController.text,
                        ),
                        icon: const Icon(Icons.search),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: _buildSearchResultContent()),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      radius: 20,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, size: 30),
                        onPressed: _toggleSearchPanel,
                      ),
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  radius: 20,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.add, size: 34),
                    onPressed: _toggleSearchPanel,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSearchResultContent() {
    if (_isSearchingBooks) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF3B30)),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Text(
          _searchError!,
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          '本のタイトルや著者名を入力してください。',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return _buildSearchResultCard(book);
      },
    );
  }

  Widget _buildSearchResultCard(Book book) {
    final service = Provider.of<SupabaseService>(context, listen: false);

    return InkWell(
      onTap: () => _showSearchedBookDetailDialog(book),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black54, width: 1),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).cardColor,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 62,
              height: 96,
              color: Colors.grey[300],
              child: book.coverUrl.trim().isNotEmpty
                  ? Image.network(
                      book.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.menu_book, color: Colors.black54),
                    )
                  : const Icon(Icons.menu_book, color: Colors.black54),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: FutureBuilder<bool>(
                      future: service.isBookReadByCurrentUser(bookId: book.id),
                      builder: (context, snapshot) {
                        final isRead = snapshot.data ?? false;
                        return SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: const Color(0xFFFF1F1F),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                            ),
                            onPressed: () async {
                              if (!isRead) {
                                await service.markBookAsRead(bookId: book.id);
                                if (mounted) {
                                  await _loadProfileData();
                                }
                              }
                              if (!mounted) return;
                              _showSearchedBookDetailDialog(book);
                            },
                            child: Text(isRead ? '投稿する' : '読了'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        final filled = i < book.ratingAvg.floor();
                        return Icon(
                          filled ? Icons.star : Icons.star_border,
                          size: 18,
                          color: const Color(0xFFE0B400),
                        );
                      }),
                      const SizedBox(width: 6),
                      Text(
                        book.ratingAvg.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFE0B400),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.description.trim().isEmpty
                        ? 'あらすじ情報はまだ登録されていません。'
                        : book.description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSearchedBookDetailDialog(Book book) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFE9E9E9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.author,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 220,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: Text(
                        book.description.trim().isEmpty
                            ? 'あらすじ情報はまだ登録されていません。'
                            : book.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1E1E1E),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
