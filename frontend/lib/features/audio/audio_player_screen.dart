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
  final String? audioUrl;
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
  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  void _startPlayback() {
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      String playUrl = widget.audioUrl!;
      if (playUrl.startsWith('/')) {
        playUrl = 'https://srishty-backend.onrender.com$playUrl';
      }
      
      ref.read(playerNotifierProvider.notifier).play(playUrl);
      debugPrint('Playback requested for: $playUrl');
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = widget.audioUrl != null && widget.audioUrl!.isNotEmpty;
    final playerState = ref.watch(playerNotifierProvider);
    final playerNotifier = ref.read(playerNotifierProvider.notifier);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background cover art
          widget.coverUrl.isEmpty
              ? Container(color: Colors.grey[900])
              : (widget.coverUrl.startsWith('http')
                  ? CachedNetworkImage(imageUrl: widget.coverUrl, fit: BoxFit.cover, errorWidget: (c, u, e) => Container(color: Colors.grey[900]))
                  : (kIsWeb
                      ? Image.network(widget.coverUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[900]))
                      : Image.file(File(widget.coverUrl), fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[900])))),
          GlassmorphicContainer(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
            blur: 40,
            alignment: Alignment.center,
            border: 0,
            linearGradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.75)]),
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
                      IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded, color: Colors.white)),
                    ],
                  ),
                ),
                const Spacer(),
                // Cover
                Hero(
                  tag: 'audio-cover-${widget.bookId}',
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.75,
                    height: MediaQuery.of(context).size.width * 0.75,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 15))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: widget.coverUrl.isEmpty
                          ? Container(color: Colors.grey[900], child: const Icon(Icons.music_note_rounded, size: 80, color: Colors.white24))
                          : (widget.coverUrl.startsWith('http')
                              ? CachedNetworkImage(imageUrl: widget.coverUrl, fit: BoxFit.cover, errorWidget: (c, u, e) => Container(color: Colors.grey[900]))
                              : (kIsWeb
                                  ? Image.network(widget.coverUrl, fit: BoxFit.cover)
                                  : Image.file(File(widget.coverUrl), fit: BoxFit.cover))),
                    ),
                  ),
                ),
                const Spacer(),
                // Title & Author
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(widget.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(widget.author, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                if (hasAudio) ...[
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
                      IconButton(onPressed: () => playerNotifier.seek(playerState.position - const Duration(seconds: 10)), icon: const Icon(Icons.replay_10_rounded, size: 35, color: Colors.white)),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () => playerNotifier.togglePlay(),
                        child: Container(
                          width: 80, height: 80,
                          decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
                          child: Icon(playerState.status == PlayerStatus.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 50, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 20),
                      IconButton(onPressed: () => playerNotifier.seek(playerState.position + const Duration(seconds: 10)), icon: const Icon(Icons.forward_10_rounded, size: 35, color: Colors.white)),
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
                ] else ...[
                  // No audio
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.mic_off_rounded, size: 48, color: Colors.white38),
                        SizedBox(height: 12),
                        Text('No audio available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
                        SizedBox(height: 6),
                        Text('The author has not recorded audio for this story yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
