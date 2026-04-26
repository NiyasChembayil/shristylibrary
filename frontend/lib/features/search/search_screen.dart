import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/search_provider.dart';
import '../../providers/book_provider.dart';
import '../../widgets/book_card.dart';
import '../book/book_detail_screen.dart';
import '../audio/audio_player_screen.dart';
import '../../models/book_model.dart';
import '../feed/widgets/post_card.dart';
import '../profile/profile_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(searchProvider.notifier).fetchDiscovery();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final isSearching = _searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(),
            Expanded(
              child: isSearching 
                ? _buildSearchResults(searchState)
                : _buildExploreGrid(searchState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 55,
        borderRadius: 20,
        blur: 20,
        alignment: Alignment.center,
        border: 1,
        linearGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)]
        ),
        borderGradient: LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.05)]
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => ref.read(searchProvider.notifier).searchAll(value),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search stories, authors, tags...',
            hintStyle: TextStyle(color: Colors.white38),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.white54),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildExploreGrid(SearchState state) {
    if (state.isLoading) return _buildShimmerLoading();

    // Flatten discovery into a single list with badges and ensure uniqueness
    final Map<int, _ExploreTileData> uniqueTiles = {};
    
    for (var b in state.mostlyReadBooks) {
      uniqueTiles[b.id] = _ExploreTileData(book: b, badge: 'Trending', color: Colors.orange);
    }
    for (var b in state.socialHits) {
      if (!uniqueTiles.containsKey(b.id)) {
        uniqueTiles[b.id] = _ExploreTileData(book: b, badge: 'Mutual Interest', color: const Color(0xFF6C63FF));
      }
    }
    for (var b in state.localHits) {
      if (!uniqueTiles.containsKey(b.id)) {
        uniqueTiles[b.id] = _ExploreTileData(book: b, badge: 'Popular Locally', color: const Color(0xFF00D2FF));
      }
    }

    final List<_ExploreTileData> allTiles = uniqueTiles.values.toList();

    if (allTiles.isEmpty && state.trendingPosts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_outlined, size: 60, color: Colors.white10),
            SizedBox(height: 16),
            Text('Discover new worlds...', style: TextStyle(color: Colors.white24, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(searchProvider.notifier).fetchDiscovery(),
      color: const Color(0xFF6C63FF),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // 1. Famous Feed Section
          if (state.trendingPosts.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Famous Feed',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(
              height: 280,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                scrollDirection: Axis.horizontal,
                itemCount: state.trendingPosts.length,
                itemBuilder: (context, index) {
                  final post = state.trendingPosts[index];
                  return SizedBox(
                    width: MediaQuery.of(context).size.width * 0.85,
                    child: PostCard(post: post),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 2. Discover Stories Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Discover Stories',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // 3. Books Grid
          MasonryGridView.count(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allTiles.length,
            itemBuilder: (context, index) {
              final data = allTiles[index];
              final bool isBig = index % 7 == 0;
              return _buildExploreTile(data, index, isBig: isBig);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExploreTile(_ExploreTileData data, int index, {bool isBig = false}) {
    return GestureDetector(
      onTap: () => _navigateToDetail(data.book),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            data.book.coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: data.book.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 150,
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Center(child: Icon(Icons.book, color: Colors.white12)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150,
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Center(child: Icon(Icons.error_outline, color: Colors.white24)),
                    ),
                  )
                : Container(
                    height: 150,
                    color: Colors.white.withValues(alpha: 0.05),
                    child: const Center(child: Icon(Icons.book, color: Colors.white24, size: 40)),
                  ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
            // Context Badge (Top Left)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.badge,
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            // Floating Meta (Trending indicator)
            if (data.badge == 'Trending')
              const Positioned(
                bottom: 8,
                right: 8,
                child: Icon(Icons.flash_on_rounded, color: Colors.orangeAccent, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(SearchState state) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
    if (state.books.isEmpty && state.profiles.isEmpty) return _buildEmptyState();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        if (state.profiles.isNotEmpty) ...[
          const Text('Users',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 15),
          ...state.profiles.map((profile) => Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ProfileScreen(targetUserId: profile.userId)),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF6C63FF),
                    backgroundImage: profile.avatar != null
                        ? NetworkImage(profile.avatar!)
                        : null,
                    child: profile.avatar == null
                        ? Text(profile.username.isNotEmpty ? profile.username[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white))
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(profile.username,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                      if (profile.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 16),
                      ],
                    ],
                  ),
                  subtitle: Text(profile.role,
                      style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                ),
              )),
          const SizedBox(height: 20),
        ],
        if (state.books.isNotEmpty) ...[
          const Text('Stories',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 15),
          ...state.books.map((book) => Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: BookCard(
                    id: book.id,
                    title: book.title,
                    author: book.authorName,
                    authorProfileId: book.authorProfileId,
                    isAuthorFollowing: book.isAuthorFollowing,
                    coverUrl: book.coverUrl,
                    likes: book.likesCount,
                    downloads: book.downloadsCount,
                    authorIsVerified: book.authorIsVerified,
                    onPlay: () => _playVoice(book),
                    onTap: () => _navigateToDetail(book)),
              )),
        ],
      ],
    );
  }

  void _playVoice(BookModel book) {
    ref.read(bookProvider.notifier).recordRead(book.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioPlayerScreen(
          bookId: book.id,
          title: book.title,
          author: book.authorName,
          coverUrl: book.coverUrl,
          chapters: book.chapters,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 80, color: Colors.white10),
          const SizedBox(height: 15),
          const Text('No Results Found.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white24)),
          const Text('Try searching for something else.', style: TextStyle(color: Colors.white10)),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.1),
      highlightColor: Colors.white.withValues(alpha: 0.2),
      child: MasonryGridView.count(
        padding: const EdgeInsets.all(10),
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: 12,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          height: index % 3 == 0 ? 200 : 120,
        ),
      ),
    );
  }

  void _navigateToDetail(BookModel book) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => BookDetailScreen(
          id: book.id,
          title: book.title,
          author: book.authorName,
          coverUrl: book.coverUrl,
          description: book.description,
        ),
      ),
    );
  }
}

class _ExploreTileData {
  final BookModel book;
  final String badge;
  final Color color;

  _ExploreTileData({required this.book, required this.badge, required this.color});
}
