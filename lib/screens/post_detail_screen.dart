import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/post.dart';
import '../models/post_reply.dart';
import '../services/supabase_service.dart';
import '../widgets/post_card.dart';
import '../widgets/post_reply_dialog.dart';
import 'user_profile_screen.dart';
import 'report_post_dialog.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    this.highlightedReplyId,
    this.onOpenProfile,
  });

  final String postId;
  final String? highlightedReplyId;
  final ValueChanged<String>? onOpenProfile;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  List<PostReply> _replies = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final service = Provider.of<SupabaseService>(context, listen: false);
    final post = await service.fetchPostById(widget.postId);
    final groupedReplies = await service.fetchRepliesForPosts(<String>[
      widget.postId,
    ]);
    if (!mounted) return;
    setState(() {
      _post = post;
      _replies = groupedReplies[widget.postId] ?? const [];
      _isLoading = false;
    });
  }

  Future<void> _reply(PostReply? parentReply) async {
    final service = Provider.of<SupabaseService>(context, listen: false);
    final canReply = await service.canCreatePostReplies();
    if (!mounted) return;
    if (!canReply) {
      await showPostReplyLockedDialog(context: context);
      return;
    }
    final posted = await showPostReplyDialog(
      context: context,
      postId: widget.postId,
      parentReplyId: parentReply?.id,
      replyToUsername: parentReply?.username,
    );
    if (!posted || !mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('返信を投稿しました。')));
  }

  Future<void> _reportReply(PostReply reply) async {
    final service = Provider.of<SupabaseService>(context, listen: false);
    if (!service.canWrite) {
      final result = await Navigator.of(context).pushNamed('/login');
      if (!mounted || (result != true && !service.canWrite)) return;
    }
    if (reply.profileId == service.activeProfileId) return;
    await showReplyReportDialog(context: context, replyId: reply.id);
  }

  Future<void> _openProfile(String profileId) async {
    final openInMainShell = widget.onOpenProfile;
    if (openInMainShell != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      openInMainShell(profileId);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => UserProfileScreen(
          profileId: profileId,
          onBack: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<SupabaseService>(context, listen: false);
    final post = _post;
    return Scaffold(
      appBar: AppBar(title: const Text('投稿と返信')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : post == null
          ? const Center(child: Text('投稿を表示できません。'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PostCard(
                  post: post,
                  replies: _replies,
                  highlightedReplyId: widget.highlightedReplyId,
                  concealSpoiler: post.profileId != service.activeProfileId,
                  onUserTap: () => _openProfile(post.profileId),
                  onReplyUserTap: _openProfile,
                  onReply: _reply,
                  onReplyReport: _reportReply,
                  concealReplySpoiler: (reply) =>
                      reply.profileId != service.activeProfileId,
                  canReportReply: (reply) =>
                      service.activeProfileId.isEmpty ||
                      reply.profileId != service.activeProfileId,
                ),
              ],
            ),
    );
  }
}
