import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/my_books_provider.dart';
import '../../widgets/book_card.dart';
import '../book/book_detail_screen.dart';
import '../audio/audio_player_screen.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/book_provider.dart';

class AudioLibraryScreen extends ConsumerStatefulWidget {
  const AudioLibraryScreen({super.key});

  @override
  ConsumerState<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends ConsumerState<AudioLibraryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(myBooksProvider.notifier).fetchMyBooks());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myBooksProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 20, 10, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => ref.read(navigationProvider.notifier).state = 0, // Go to Home
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'My Library',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search by title or author...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            Expanded(
              child: _buildContent(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(MyBooksState state) {
    if (state.isLoading && state.books.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
    }

    final filteredBooks = _searchQuery.isEmpty 
      ? state.books 
      : state.books.where((book) => 
          book.title.toLowerCase().contains(_searchQuery) || 
          book.authorName.toLowerCase().contains(_searchQuery)
        ).toList();

    if (filteredBooks.isEmpty) {
      return _searchQuery.isEmpty ? _buildEmptyState() : _buildNoSearchResults();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(myBooksProvider.notifier).fetchMyBooks(),
      color: const Color(0xFF6C63FF),
      backgroundColor: const Color(0xFF1E1E2E),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: filteredBooks.length,
        itemBuilder: (context, index) {
          final book = filteredBooks[index];
          return BookCard(
            id: book.id,
            title: book.title,
            author: book.authorName,
            authorProfileId: book.authorProfileId,
            isAuthorFollowing: book.isAuthorFollowing,
            coverUrl: book.coverUrl,
            likes: book.likesCount,
            downloads: book.downloadsCount,
            authorIsVerified: book.authorIsVerified,
            onPlay: () {
              if (book.audioUrl == null || book.audioUrl!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No audio available for this story yet.'))
                );
                return;
              }

              // Record a read event for the stats
              ref.read(bookProvider.notifier).recordRead(book.id);
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AudioPlayerScreen(
                    bookId: book.id,
                    title: book.title,
                    author: book.authorName,
                    coverUrl: book.coverUrl,
                    chapters: book.chapters,
                    audioUrl: book.audioUrl,
                  ),
                ),
              );
            },
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookDetailScreen(
                    id: book.id,
                    title: book.title,
                    author: book.authorName,
                    coverUrl: book.coverUrl,
                    description: book.description,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 80, color: Colors.white24),
          const SizedBox(height: 20),
          const Text('No matches found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 10),
          Text('Try searching for something else in your library.', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_books_rounded, size: 80, color: Colors.white24),
            const SizedBox(height: 20),
            const Text('Your library is empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 10),
            const Text(
              'Purchase stories or publish your own to see them here.', 
              style: TextStyle(color: Colors.white38), 
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => ref.read(navigationProvider.notifier).state = 0, // Go to Home (Store)
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Browse Stories', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
