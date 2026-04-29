import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:animations/animations.dart';
import '../../widgets/mini_book_card.dart';
import '../book/book_detail_screen.dart';
import '../audio/audio_player_screen.dart';
import '../../providers/book_provider.dart';
import '../notifications/notification_screen.dart';
import '../../providers/notification_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/platform_settings_provider.dart';
import '../../providers/category_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      ref.read(bookProvider.notifier).fetchBooks();
      ref.read(notificationProvider.notifier).fetchNotifications();
      final count = await ref.read(notificationProvider.notifier).fetchUnreadCount();
      ref.read(unreadNotificationCountProvider.notifier).state = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(bookProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App bar row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${DateTime.now().hour < 12 ? "Morning" : DateTime.now().hour < 17 ? "Afternoon" : "Evening"},',
                        style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        ref.watch(authProvider).profile?.username ?? 'Storyteller',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => ref.read(navigationProvider.notifier).state = 2,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.search_rounded, size: 24, color: Colors.white70),
                        ),
                      ),
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.notifications_none_rounded, size: 24),
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Body — switches based on feed state
            Expanded(
              child: _buildBody(feedState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BookFeedState feedState) {
    switch (feedState.status) {
      case BookFeedStatus.initial:
      case BookFeedStatus.loading:
        return _buildShimmerLoading();

      case BookFeedStatus.empty:
        return _buildEmptyState();

      case BookFeedStatus.error:
        return _buildErrorState(feedState.error);

      case BookFeedStatus.loaded:
        final allBooks = List.of(feedState.books);
        final platformSettings = ref.watch(platformSettingsProvider);
        final boostedCategories = ref.watch(categoryProvider).where((c) => c.isBoosted).toList();
        
        // Prepare sub-lists
        final topPicks = allBooks.take(10).toList();
        
        // Sort by likes for Top 10 in India
        final top10Books = List.of(allBooks)
          ..sort((a, b) => b.likesCount.compareTo(a.likesCount));
        final top10 = top10Books.take(10).toList();
        
        // Continue Reading: Books in library with some progress
        final continueReading = allBooks.where((b) => b.isInLibrary).take(5).toList();
        
        // Remaining books or random for Secret Obsessions
        final obsessions = allBooks.length > 20 
            ? allBooks.skip(20).toList() 
            : allBooks.reversed.toList();

        return RefreshIndicator(
          color: const Color(0xFF6C63FF),
          backgroundColor: const Color(0xFF1E1E2E),
          onRefresh: () => ref.read(bookProvider.notifier).fetchBooks(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120, top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (platformSettings?.globalAnnouncement != null && platformSettings!.globalAnnouncement!.isNotEmpty)
                  _buildAnnouncementBanner(platformSettings.globalAnnouncement!),
                if (boostedCategories.isNotEmpty)
                  _buildBoostedCategories(boostedCategories),
                if (continueReading.isNotEmpty)
                  _buildHorizontalSection(
                    context,
                    title: 'Continue Reading',
                    books: continueReading,
                    isProgressSection: true,
                  ),
                const SizedBox(height: 10),
                _buildHorizontalSection(
                  context,
                  title: 'Top picks for you',
                  books: topPicks,
                ),
                const SizedBox(height: 30),
                _buildHorizontalSection(
                  context,
                  title: 'Top 10 in India',
                  books: top10,
                  showRank: true,
                ),
                const SizedBox(height: 30),
                _buildHorizontalSection(
                  context,
                  title: 'Secret obsessions 🖤',
                  subtitle: 'Unraveling the darkest truths',
                  books: obsessions,
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildHorizontalSection(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List books,
    bool showRank = false,
    bool isProgressSection = false,
  }) {
    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: 270, // To comfortably fit image + number shadow + text row
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return OpenContainer(
                closedColor: Colors.transparent,
                openColor: Theme.of(context).scaffoldBackgroundColor,
                closedElevation: 0,
                transitionType: ContainerTransitionType.fadeThrough,
                openBuilder: (context, _) => BookDetailScreen(
                  id: book.id,
                  title: book.title,
                  author: book.authorName,
                  coverUrl: book.coverUrl,
                  description: book.description,
                ),
                closedBuilder: (context, openContainer) => MiniBookCard(
                  title: book.title,
                  coverUrl: book.coverUrl,
                  categoryName: book.categoryName,
                  views: book.totalReads > 0 ? book.totalReads : book.likesCount,
                  rank: showRank ? (index + 1) : null,
                  readingProgress: isProgressSection ? 0.65 : null, // Mock progress for demo
                  onTap: openContainer,
                  onPlay: () {
                    // Record a read event for the stats
                    ref.read(bookProvider.notifier).recordRead(book.id);
                    
                    // Find first chapter with audio
                    final firstAudioChapter = book.chapters.firstWhere(
                      (c) => c.audioUrl != null && c.audioUrl!.isNotEmpty,
                      orElse: () => book.chapters.first,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AudioPlayerScreen(
                          bookId: book.id,
                          title: book.title,
                          author: book.authorName,
                          coverUrl: book.coverUrl,
                          chapters: book.chapters,
                          audioUrl: firstAudioChapter.audioUrl,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[800]!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          height: 400,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white10),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_rounded, size: 80, color: Colors.white24),
          const SizedBox(height: 20),
          const Text('No Books Yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 10),
          const Text('Check back soon — stories are on their way!', style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 30),
          TextButton.icon(
            onPressed: () => ref.read(bookProvider.notifier).fetchBooks(),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6C63FF)),
            label: const Text('Refresh', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 80, color: Colors.white24),
            const SizedBox(height: 20),
            const Text('No Connection', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 10),
            const Text(
              'Could not reach the server.\nCheck your internet connection and try again.',
              style: TextStyle(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => ref.read(bookProvider.notifier).fetchBooks(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Try Again', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  Widget _buildAnnouncementBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoostedCategories(List<CategoryModel> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            'Explore Seasonal Genres 🚀',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: FilterChip(
                  label: Text(cat.name),
                  labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  side: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onSelected: (_) {
                    // Logic to filter books by category could go here
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
