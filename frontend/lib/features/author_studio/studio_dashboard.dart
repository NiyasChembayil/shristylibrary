import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../../providers/author_provider.dart';
import '../../widgets/mini_book_card.dart';
import 'write_screen.dart';
import 'media_upload_screen.dart';
import 'story_bible_screen.dart';

class StudioDashboard extends ConsumerStatefulWidget {
  const StudioDashboard({super.key});

  @override
  ConsumerState<StudioDashboard> createState() => _StudioDashboardState();
}

class _StudioDashboardState extends ConsumerState<StudioDashboard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authorStudioProvider.notifier).fetchMyStories());
  }

  @override
  Widget build(BuildContext context) {
    final studioState = ref.watch(authorStudioProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (studioState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
            )
          else if (studioState.stories.isEmpty)
            _buildEmptyState()
          else
            _buildStoriesGrid(studioState.stories),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateStoryModal(context),
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Story', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: const Color(0xFF0F0F1E),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Author Studio', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              colors: [
                const Color(0xFF6C63FF).withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories_rounded, size: 80, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 20),
            const Text('Your studio is empty', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Start writing your masterpiece today!', style: TextStyle(color: Colors.white38)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesGrid(List stories) {
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 15,
          childAspectRatio: 0.6,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final story = stories[index];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WriteScreen(bookId: story.id)),
              ),
              child: Stack(
                children: [
                  MiniBookCard(
                    title: story.title,
                    coverUrl: story.coverUrl,
                    categoryName: story.categoryName,
                    views: story.totalReads,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WriteScreen(bookId: story.id)),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF6C63FF)),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => StoryBibleScreen(bookId: story.id, bookTitle: story.title)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.settings, size: 18, color: Colors.white),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => MediaUploadScreen(book: story)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: stories.length,
        ),
      ),
    );
  }

  void _showCreateStoryModal(BuildContext context) {
    // Basic modal for now, just to show the flow
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassmorphicContainer(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.7,
        borderRadius: 30,
        blur: 20,
        alignment: Alignment.center,
        border: 2,
        linearGradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.05),
        ]),
        borderGradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          const Color(0xFF6C63FF).withValues(alpha: 0.5),
          const Color(0xFFFF6584).withValues(alpha: 0.5),
        ]),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Start a New Story', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 30),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Title',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              // More fields would go here...
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  child: const Text('Create Story', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
