import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/book.dart';
import '../models/user_profile.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../widgets/book_card.dart';

class UserProfileScreen extends StatefulWidget {
  final VoidCallback onBack;

  const UserProfileScreen({super.key, required this.onBack});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserProfile? _profile;
  List<Post> _userPosts = [];
  List<Book> _collections = [];
  List<Book> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      appBar: AppBar(
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
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF3B30)),
            )
          : _profile == null
          ? const Center(child: Text('プロフィールの読み込みに失敗しました。')) // ⭕ データ未取得時の安全ガード
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
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
                          _buildGridTab(_collections, 'コレクションはありません。'),
                          _buildGridTab(_favorites, 'お気に入りの本はありません。'),
                        ],
                      ),
                    ),
                  ],
                ),
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

  Widget _buildGridTab(List<Book> booksList, String emptyMessage) {
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
        return BookCard(book: book, width: double.infinity, height: 140);
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
