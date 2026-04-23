import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/audio_player_screen.dart';
import 'reader_screen.dart';
import '../../providers/book_provider.dart';
import '../../widgets/follow_button.dart';
import '../profile/profile_screen.dart';

class BookDetailScreen extends ConsumerWidget {
  final int id;
  final String title;
  final String author;
  final String coverUrl;
  final String description;

  const BookDetailScreen({
    super.key,
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.description,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(currentBookProvider(id));
    // All books are free and accessible now

    return bookAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 60, color: Colors.white24),
              const SizedBox(height: 16),
              Text('Could not load book', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(currentBookProvider(id)),
                child: const Text('Retry', style: TextStyle(color: Color(0xFF6C63FF))),
              ),
            ],
          ),
        ),
      ),
      data: (book) {
        if (book == null) {
          return const Scaffold(body: Center(child: Text('Book not found')));
        }
        return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 450,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'book-cover-${book.id}',
                      child: CachedNetworkImage(
                        imageUrl: book.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const ColoredBox(color: Color(0xFF1E1E2E)),
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF1E1E2E),
                          child: Icon(Icons.menu_book_rounded, size: 80, color: Colors.white24),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fadeIn(
                      child: Text(book.title, style: Theme.of(context).textTheme.displayLarge),
                    ),
                    const SizedBox(height: 10),
                    _fadeIn(
                      delay: 100,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(targetUserId: book.authorProfileId),
                                ),
                              );
                            },
                            child: Text(
                              'by ${book.authorName}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF6C63FF),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          FollowButton(
                            authorUsername: book.authorName,
                            authorProfileId: book.authorProfileId,
                            initialIsFollowing: book.isAuthorFollowing,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Stat columns... (no change)
                    _fadeIn(
                      delay: 200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn('${book.likesCount}', 'Likes'),
                          _buildStatColumn('${book.totalReads}', 'Reads'),
                          _buildStatColumn('${book.downloadsCount}', 'Downloads'),
                          _buildStatColumn('${book.chapters.length}', 'Chapters'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    _fadeIn(
                      delay: 300,
                      child: Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _fadeIn(
                      delay: 400,
                      child: Text(
                        book.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 150),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomSheet: Container(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Record a read event for the stats
                    ref.read(bookProvider.notifier).recordRead(id);
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReaderScreen(
                          bookId: id,
                          title: book.title,
                          chapters: book.chapters,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text(
                    'Read Now',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Like Button
              GlassmorphicContainer(
                width: 70,
                height: 70,
                borderRadius: 20,
                blur: 10,
                alignment: Alignment.center,
                border: 1,
                linearGradient: LinearGradient(colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05)
                ]),
                borderGradient: LinearGradient(colors: [
                  book.isLiked
                      ? Colors.redAccent.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.5),
                  Colors.white.withValues(alpha: 0.2)
                ]),
                child: IconButton(
                  onPressed: () => ref.read(bookProvider.notifier).likeBook(id, ref),
                  icon: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        book.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: book.isLiked ? Colors.redAccent : Colors.white,
                        size: 24,
                      ),
                      Text(
                        '${book.likesCount}',
                        style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Download/Library Toggle Button
              GlassmorphicContainer(
                width: 70,
                height: 70,
                borderRadius: 20,
                blur: 10,
                alignment: Alignment.center,
                border: 1,
                linearGradient: LinearGradient(colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05)
                ]),
                borderGradient: LinearGradient(colors: [
                  book.isInLibrary
                      ? Colors.greenAccent.withValues(alpha: 0.5)
                      : const Color(0xFF6C63FF).withValues(alpha: 0.5),
                  Colors.white.withValues(alpha: 0.2)
                ]),
                child: IconButton(
                  onPressed: () async {
                    await ref.read(bookProvider.notifier).toggleLibrary(id, ref);
                    if (context.mounted) {
                      final message = book.isInLibrary 
                        ? 'Story removed from Library' 
                        : 'Story added to Library!';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: book.isInLibrary ? Colors.black87 : const Color(0xFF6C63FF),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    book.isInLibrary
                        ? Icons.task_alt_rounded
                        : Icons.cloud_download_rounded,
                    color: book.isInLibrary
                        ? Colors.greenAccent
                        : Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Audio Button
              GlassmorphicContainer(
                width: 70,
                height: 70,
                borderRadius: 20,
                blur: 10,
                alignment: Alignment.center,
                border: 1,
                linearGradient: LinearGradient(colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05)
                ]),
                borderGradient: LinearGradient(colors: [
                  Colors.white.withValues(alpha: 0.5),
                  Colors.white.withValues(alpha: 0.2)
                ]),
                child: IconButton(
                  onPressed: () {
                    // Find first chapter with audio
                    final chapters = book.chapters;
                    final audioChapter = chapters.any((c) => c.audioUrl != null && c.audioUrl!.isNotEmpty)
                        ? chapters.firstWhere((c) => c.audioUrl != null && c.audioUrl!.isNotEmpty)
                        : null;

                    if (audioChapter == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No audio available for this story yet.'))
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AudioPlayerScreen(
                          bookId: id,
                          title: book.title,
                          author: book.authorName,
                          coverUrl: book.coverUrl,
                          audioUrl: audioChapter.audioUrl,
                          chapters: book.chapters,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.headphones_rounded,
                      color: Colors.white, size: 30),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _fadeIn({required Widget child, int delay = 0}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
        );
      },
      child: child,
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}
