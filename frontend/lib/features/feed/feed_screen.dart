import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/post_provider.dart';
import 'widgets/post_card.dart';
import 'create_post_screen.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {

  @override
  void initState() {
    super.initState();
    // Load feed
    Future.microtask(() {
      ref.read(postFeedProvider.notifier).loadFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postFeedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: const Color(0xFF0A0A12),
              elevation: 0,
              title: Row(
                children: [
                  const Icon(Icons.auto_stories, color: Color(0xFF6C63FF), size: 28),
                  const SizedBox(width: 10),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                    ).createShader(bounds),
                    child: const Text(
                      'Feed',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  onPressed: () {
                    ref.read(postFeedProvider.notifier).loadFeed();
                  },
                ),
              ],
            ),
          ],
          body: _buildFeedTab(state),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
          ref.read(postFeedProvider.notifier).loadFeed();
        },
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFeedTab(PostFeedState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      );
    }
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
                color: Colors.grey, size: 60),
            const SizedBox(height: 16),
            Text(
              'Could not load feed',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.read(postFeedProvider.notifier).loadFeed(),
              icon: const Icon(Icons.refresh, color: Color(0xFF6C63FF)),
              label: const Text('Retry', style: TextStyle(color: Color(0xFF6C63FF))),
            ),
          ],
        ),
      );
    }
    if (state.feed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📚', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              'Your feed is empty!\nFollow writers to see their posts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 16, height: 1.5),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF6C63FF),
      onRefresh: () => ref.read(postFeedProvider.notifier).loadFeed(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: state.feed.length,
        itemBuilder: (context, index) => PostCard(post: state.feed[index]),
      ),
    );
  }

}
