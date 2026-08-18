import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/supabase_service.dart';

class FollowListScreen extends StatefulWidget {
  const FollowListScreen({
    super.key,
    required this.profileId,
    required this.followers,
    required this.onProfileTap,
  });

  final String profileId;
  final bool followers;
  final ValueChanged<UserProfile> onProfileTap;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<UserProfile> _profiles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await Provider.of<SupabaseService>(context, listen: false)
        .fetchProfileFollowList(
          profileId: widget.profileId,
          followers: widget.followers,
        );
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.followers ? 'フォロワー' : 'フォロー')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
          ? Center(
              child: Text(
                widget.followers ? 'フォロワーはいません。' : 'フォローしているユーザーはいません。',
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _profiles.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final profile = _profiles[index];
                  return ListTile(
                    onTap: () => widget.onProfileTap(profile),
                    leading: CircleAvatar(
                      backgroundImage: profile.avatarUrl.isEmpty
                          ? null
                          : NetworkImage(profile.avatarUrl),
                      child: profile.avatarUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      profile.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      profile.userId.isEmpty ? '' : '@${profile.userId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: profile.isPrivate
                        ? const Icon(Icons.lock_outline, size: 18)
                        : const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
    );
  }
}
