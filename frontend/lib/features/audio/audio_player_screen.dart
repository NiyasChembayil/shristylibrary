import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:audio_service/audio_service.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/audio_provider.dart';
import '../../models/book_model.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final int bookId;
  final String title;
  final String author;
  final String coverUrl;
  final String? audioUrl; // Book level fallback
  final List<ChapterModel> chapters;

  const AudioPlayerScreen({
    super.key,
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.chapters,
    this.audioUrl,
  });

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  int currentChapterIndex = -1; // -1 means book-level audio

  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  void _startPlayback() {
    String? playUrl = widget.audioUrl;
    
    // Find first chapter with audio if book audio is missing
    if (playUrl == null || playUrl.isEmpty) {
        final chapterWithAudio = widget.chapters.indexWhere((c) => c.audioUrl != null && c.audioUrl!.isNotEmpty);
        if (chapterWithAudio != -1) {
            currentChapterIndex = chapterWithAudio;
            playUrl = widget.chapters[chapterWithAudio].audioUrl;
        }
    }

    if (playUrl == null || playUrl.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playUrl(playUrl!);
    });
  }

  void _playUrl(String url) {
    String playUrl = url;
    if (playUrl.startsWith('/')) {
      playUrl = 'https://srishty-backend.onrender.com$playUrl';
    }
    
    ref.read(playerNotifierProvider.notifier).play(playUrl);
    debugPrint('Playback requested for: $playUrl');
  }

  void _switchChapter(int index) {
      final url = widget.chapters[index].audioUrl;
      if (url != null && url.isNotEmpty) {
          setState(() {
              currentChapterIndex = index;
          });
          _playUrl(url);
      } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No audio available for ${widget.chapters[index].title}'))
          );
      }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerNotifierProvider);
    final playerNotifier = ref.read(playerNotifierProvider.notifier);

    String displayTitle = currentChapterIndex == -1 ? widget.title : widget.chapters[currentChapterIndex].title;
    String displaySubtitle = currentChapterIndex == -1 ? widget.author : widget.title;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background cover art
          widget.coverUrl.isEmpty
              ? Container(color: Colors.grey[900])
              : CachedNetworkImage(imageUrl: widget.coverUrl, fit: BoxFit.cover, errorWidget: (c, u, e) => Container(color: Colors.grey[900])),
          GlassmorphicContainer(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
            blur: 40,
            alignment: Alignment.center,
            border: 0,
            linearGradient: LinearGradient(colors: [Colors.black.withOpacity(0.55), Colors.black.withOpacity(0.75)]),
            borderGradient: const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 40, color: Colors.white)),
                      const Text('Now Playing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                      IconButton(
                          onPressed: () {
                              showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => GlassmorphicContainer(
                                      width: double.infinity,
                                      height: 400,
                                      borderRadius: 30,
                                      blur: 20,
                                      alignment: Alignment.center,
                                      border: 1,
                                      linearGradient: LinearGradient(colors: [Colors.black87, Colors.black54]),
                                      borderGradient: LinearGradient(colors: [Colors.white24, Colors.transparent]),
                                      child: Column(
                                          children: [
                                              const Padding(
                                                  padding: EdgeInsets.all(20),
                                                  child: Text('Chapters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                              ),
                                              Expanded(
                                                  child: ListView.builder(
                                                      itemCount: widget.chapters.length,
                                                      itemBuilder: (context, index) {
                                                          final chap = widget.chapters[index];
                                                          final hasAudio = chap.audioUrl != null && chap.audioUrl!.isNotEmpty;
                                                          return ListTile(
                                                              leading: Icon(
                                                                  currentChapterIndex == index ? Icons.play_circle_fill : Icons.menu_book,
                                                                  color: currentChapterIndex == index ? const Color(0xFF6C63FF) : Colors.white70
                                                              ),
                                                              title: Text(chap.title, style: TextStyle(color: hasAudio ? Colors.white : Colors.white38)),
                                                              trailing: hasAudio ? const Icon(Icons.headphones, color: Colors.white54, size: 16) : null,
                                                              onTap: () {
                                                                  Navigator.pop(context);
                                                                  _switchChapter(index);
                                                              },
                                                          );
                                                      },
                                                  ),
                                              ),
                                          ],
                                      ),
                                  ),
                              );
                          },
                          icon: const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 30)
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Cover
                Hero(
                  tag: 'audio-cover-${widget.bookId}',
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: MediaQuery.of(context).size.width * 0.7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: widget.coverUrl.isEmpty
                          ? Container(color: Colors.grey[900], child: const Icon(Icons.music_note_rounded, size: 80, color: Colors.white24))
                          : CachedNetworkImage(imageUrl: widget.coverUrl, fit: BoxFit.cover, errorWidget: (c, u, e) => Container(color: Colors.grey[900])),
                    ),
                  ),
                ),
                const Spacer(),
                // Title & Author
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(displayTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(displaySubtitle, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Slider(
                        value: playerState.position.inSeconds.toDouble().clamp(0.0, playerState.totalDuration.inSeconds.toDouble().clamp(1.0, double.infinity)),
                        max: playerState.totalDuration.inSeconds.toDouble().clamp(1.0, double.infinity),
                        onChanged: (v) => playerNotifier.seek(Duration(seconds: v.toInt())),
                        activeColor: const Color(0xFF6C63FF),
                        inactiveColor: Colors.white24,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(playerState.position), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(_formatDuration(playerState.totalDuration), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        onPressed: currentChapterIndex > 0 ? () => _switchChapter(currentChapterIndex - 1) : null,
                        icon: const Icon(Icons.skip_previous_rounded, size: 45, color: Colors.white)
                    ),
                    const SizedBox(width: 15),
                    GestureDetector(
                      onTap: () => playerNotifier.togglePlay(),
                      child: Container(
                        width: 80, height: 80,
                        decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
                        child: Icon(playerState.status == PlayerStatus.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 50, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 15),
                    IconButton(
                        onPressed: currentChapterIndex < widget.chapters.length - 1 ? () => _switchChapter(currentChapterIndex + 1) : null,
                        icon: const Icon(Icons.skip_next_rounded, size: 45, color: Colors.white)
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                OutlinedButton(
                  onPressed: () {
                    double next = playerState.playbackSpeed >= 2.0 ? 1.0 : playerState.playbackSpeed + 0.5;
                    playerNotifier.setSpeed(next);
                  },
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), foregroundColor: Colors.white),
                  child: Text('${playerState.playbackSpeed}x Speed'),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
