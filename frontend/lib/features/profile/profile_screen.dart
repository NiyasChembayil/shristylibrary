import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../models/book_model.dart';
import '../../widgets/book_card.dart';
import '../settings/settings_screen.dart';
import '../book/book_detail_screen.dart';
import 'user_list_screen.dart';
import '../../core/api_client.dart';
import '../../providers/post_provider.dart';
import '../feed/widgets/post_card.dart';
import '../../models/profile_model.dart';
import '../../providers/social_provider.dart';

final externalProfileProvider = FutureProvider.family<ProfileModel?, String>((ref, profileId) async {
  final apiClient = ref.read(apiClientProvider);
  try {
    final response = await apiClient.dio.get('accounts/profile/by_user/$profileId/');
    return ProfileModel.fromJson(response.data);
  } catch (e) {
    return null;
  }
});

final activityProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, profileId) async {
  final apiClient = ref.read(apiClientProvider);
  try {
    final response = await apiClient.dio.get('accounts/profile/$profileId/activity/');
    final data = response.data['activity'] as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  } catch (e) {
    return [];
  }
});

final authorBooksProvider = FutureProvider.family<List<BookModel>, String>((ref, authorId) async {
  final apiClient = ref.read(apiClientProvider);
  debugPrint("🚀 Fetching author books | authorId: $authorId");
  try {
    final endpoint = authorId == 'me' ? 'core/books/my_books/' : 'core/books/?author=$authorId';
    final response = await apiClient.dio.get(endpoint);
    debugPrint("✅ API Response [${response.statusCode}] for $authorId | endpoint: $endpoint");
    
    final data = response.data;
    if (data is! List) {
      return [];
    }

    final List<BookModel> validBooks = [];
    for (var j in data) {
      try {
        validBooks.add(BookModel.fromJson(j));
      } catch (err) {
        debugPrint("⚠️ Skipping book ID ${j['id']} due to parsing error: $err");
      }
    }
    debugPrint("📦 Successfully parsed ${validBooks.length} out of ${data.length} books for $authorId");
    
    if (validBooks.isEmpty && data.isNotEmpty) {
      throw Exception("Parsing failed: Found ${data.length} entries but 0 were valid. Possible model mismatch.");
    }
    
    return validBooks;
  } catch (e) {
    debugPrint("🔥 Network Error fetching author books for $authorId: $e");
    String errorMsg = e.toString();
    if (e is DioException) {
      errorMsg = "API Error [${e.response?.statusCode}]: ${e.response?.data ?? e.message}";
    }
    throw Exception(errorMsg);
  }
});

class ProfileScreen extends ConsumerStatefulWidget {
  final int? targetUserId;
  const ProfileScreen({super.key, this.targetUserId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    Future.microtask(() {
      final auth = ref.read(authProvider.notifier);
      final authState = ref.read(authProvider);
      
      auth.refreshProfile();
      
      final effectiveUserId = widget.targetUserId ?? authState.profile?.id;
      if (effectiveUserId != null) {
        ref.read(postFeedProvider.notifier).loadUserPosts(effectiveUserId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final myProfile = authState.profile;
    
    // If we have a targetUserId (navigated from post), compare it with the logged-in User ID.
    // If not, it's definitely 'me'.
    final isMe = widget.targetUserId == null || (myProfile != null && widget.targetUserId == myProfile.userId);
    
    // If it's not me, we need to load the other user's profile
    final profileAsync = !isMe 
        ? ref.watch(externalProfileProvider(widget.targetUserId!.toString()))
        : AsyncValue.data(myProfile);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, stack) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('Profile not found')));
        }

        // Use 'me' for current user (to see drafts), or profile.userId for others.
        final authorIdKey = isMe ? 'me' : profile.userId.toString();
        final authorBooksAsync = ref.watch(authorBooksProvider(authorIdKey));
        final postState = ref.watch(postFeedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  // Header with Back and Settings buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (Navigator.canPop(context))
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 24),
                        )
                      else
                        const SizedBox(width: 48), // Spacer if no back button
                      
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                        icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 28),
                      ),
                    ],
                  ),

                  // Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF1E1E2E),
                    backgroundImage: profile.avatar != null
                        ? NetworkImage(profile.avatar!)
                        : null,
                    child: profile.avatar == null
                        ? Text(
                            profile.username[0].toUpperCase(),
                            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)),
                          )
                        : null,
                  ),
                  const SizedBox(height: 15),

                  // Username
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        profile.username,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      if (profile.isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: Colors.blue, size: 20),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),


                  // Bio
                  if (profile.bio.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 15),
                      child: Text(
                        profile.bio, 
                        textAlign: TextAlign.center, 
                        style: const TextStyle(color: Colors.white54, fontSize: 13)
                      ),
                    ),

                  // Follow Button (Only for others)
                  if (!isMe)
                    Consumer(
                      builder: (context, ref, _) {
                        final socialState = ref.watch(socialProvider);
                        final isFollowing = socialState[profile.username] ?? profile.isFollowing;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 25),
                          child: SizedBox(
                            width: 200,
                            height: 45,
                            child: ElevatedButton(
                              onPressed: () async {
                                await ref.read(socialProvider.notifier).toggleFollow(profile.username, profile.id);
                                // Refresh profile to update counts
                                ref.invalidate(externalProfileProvider(profile.userId.toString()));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing ? Colors.transparent : const Color(0xFF6C63FF),
                                foregroundColor: Colors.white,
                                elevation: isFollowing ? 0 : 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: isFollowing 
                                    ? BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5)
                                    : BorderSide.none,
                                ),
                              ).copyWith(
                                overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        authorBooksAsync.when(
                          data: (books) {
                            final totalReads = books.fold<int>(0, (sum, b) => sum + b.totalReads);
                            return _buildStatItem('Reads', '$totalReads');
                          },
                          loading: () => _buildStatItem('Reads', '...'),
                          error: (_, __) => _buildStatItem('Reads', '0'),
                        ),
                        _buildVerticalDivider(),
                        _buildStatItem(
                          'Followers',
                          '${profile.followersCount}',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserListScreen(
                                  title: 'Followers',
                                  endpoint: 'accounts/profile/${profile.id}/followers/',
                                ),
                              ),
                            );
                                                    },
                        ),
                        _buildVerticalDivider(),
                        _buildStatItem(
                          'Following',
                          '${profile.followingCount}',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserListScreen(
                                  title: 'Following',
                                  endpoint: 'accounts/profile/${profile.id}/following/',
                                ),
                              ),
                            );
                                                    },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF6C63FF),
                indicatorWeight: 3,
                labelColor: const Color(0xFF6C63FF),
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Works'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Posts Tab
            _buildPostsTab(postState),
            // Works Tab
            _buildWorksTab(profile, authorBooksAsync, ref),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildPostsTab(PostFeedState state) {
    if (state.isUserPostsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
    }
    if (state.userPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.post_add_rounded, size: 60, color: Colors.white10),
            const SizedBox(height: 16),
            Text(
              "No posts yet.",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        final authParams = ref.read(authProvider);
        if (authParams.profile != null) {
          await ref.read(postFeedProvider.notifier).loadUserPosts(authParams.profile!.id);
        }
      },
      color: const Color(0xFF6C63FF),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 10, bottom: 100),
        itemCount: state.userPosts.length,
        itemBuilder: (context, index) => PostCard(post: state.userPosts[index]),
      ),
    );
  }

  Widget _buildWorksTab(ProfileModel profile, AsyncValue<List<BookModel>> booksAsync, WidgetRef ref) {
    final myProfile = ref.read(authProvider).profile;
    final isMe = widget.targetUserId == null || (myProfile != null && widget.targetUserId == myProfile.userId);
    
    return RefreshIndicator(
      onRefresh: () async {
        final key = isMe ? 'me' : profile.userId.toString();
        ref.invalidate(authorBooksProvider(key));
      },
      color: const Color(0xFF6C63FF),
      child: booksAsync.when(
        data: (myBooks) {
          if (myBooks.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNoBooksPlaceholder(),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => ref.invalidate(authorBooksProvider(isMe ? 'me' : profile.userId.toString())),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text("DIAGNOSTIC REFRESH", style: TextStyle(fontSize: 10, color: Colors.white38)),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChartSection(ref, profile.id),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isMe ? 'My Published Works' : "${profile.username}'s Works", 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    if (myBooks.isNotEmpty)
                      TextButton(onPressed: () {}, child: const Text('View All', style: TextStyle(color: Color(0xFF6C63FF)))),
                  ],
                ),
                _buildBooksList(context, myBooks),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 10),
                Text(
                  'Diagnostic Error:\n$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => ref.invalidate(authorBooksProvider(isMe ? 'me' : profile.userId.toString())),
                  child: const Text("Force Refresh"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBooksList(BuildContext context, List<BookModel> books) {
    return SizedBox(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return SizedBox(
            width: 250,
            child: Transform.scale(
              scale: 0.7,
              alignment: Alignment.topLeft,
              child: BookCard(
                id: book.id,
                title: book.title,
                author: book.authorName,
                authorProfileId: book.authorProfileId,
                isAuthorFollowing: book.isAuthorFollowing,
                coverUrl: book.coverUrl,
                likes: book.likesCount,
                downloads: book.downloadsCount,
                onPlay: () {},
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
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() => Container(height: 35, width: 1, color: Colors.white10);

  Widget _buildChartSection(WidgetRef ref, int profileId) {
    final activityAsync = ref.watch(activityProvider(profileId));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reading Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF6C63FF).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: const Text('Last 7 days', style: TextStyle(fontSize: 10, color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text('Your actual story interactions this week.', style: TextStyle(fontSize: 12, color: Colors.white38)),
          const SizedBox(height: 25),
          SizedBox(
            height: 150,
            child: activityAsync.when(
              data: (data) {
                if (data.isEmpty) return const Center(child: Text("No activity yet", style: TextStyle(color: Colors.white24)));
                
                final maxCount = data.map((e) => e['count'] as int).fold(0, (max, e) => e > max ? e : max);
                final maxY = maxCount > 10 ? (maxCount + 2).toDouble() : 10.0;

                return LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= data.length) return const SizedBox();
                            final date = DateTime.parse(data[index]['date'] as String);
                            final label = _getDayLabel(date.weekday);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['count'] as int).toDouble())).toList(),
                        isCurved: true,
                        color: const Color(0xFF6C63FF),
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                    minY: 0,
                    maxY: maxY,
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const Center(child: Icon(Icons.error_outline, color: Colors.white24)),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayLabel(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  Widget _buildNoBooksPlaceholder() {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: const Column(
        children: [
          Icon(Icons.auto_stories_rounded, size: 48, color: Colors.white24),
          SizedBox(height: 12),
          Text("You haven't published any books yet.", style: TextStyle(color: Colors.white54)),
          SizedBox(height: 6),
          Text('Tap the + tab to start creating!', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0A0A12),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
