import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MiniBookCard extends StatelessWidget {
  final String title;
  final String coverUrl;
  final String categoryName;
  final int views;
  final int? rank;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const MiniBookCard({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.categoryName,
    required this.views,
    this.rank,
    required this.onTap,
    required this.onPlay,
  });

  String _formatViews(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 200,
                  width: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: coverUrl.isEmpty
                        ? Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.book, size: 40, color: Colors.white24),
                          )
                        : (coverUrl.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: coverUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.grey[900]),
                                errorWidget: (context, url, error) => const Icon(Icons.book, size: 40, color: Colors.white24),
                              )
                            : (kIsWeb
                                ? Image.network(
                                    coverUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.book, size: 40, color: Colors.white24),
                                  )
                                : Image.file(
                                    File(coverUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.book, size: 40, color: Colors.white24),
                                  ))),
                  ),
                ),
                
                // Play overlay subtle badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),

                // Absolute Rank Number Positioned at Bottom-Left edge
                if (rank != null)
                  Positioned(
                    bottom: -20,
                    left: -10,
                    child: Text(
                      rank.toString(),
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -5,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black.withValues(alpha: 0.6),
                            offset: const Offset(0, 2),
                          ),
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black.withValues(alpha: 0.4),
                            offset: const Offset(2, 4),
                          )
                        ],
                        // Stroke effect
                        foreground: Paint()
                          ..style = PaintingStyle.fill
                          ..color = Colors.white,
                      ),
                    ),
                  ),
                  
                  // Black stroke outline behind the white number
                  if (rank != null)
                  Positioned(
                    bottom: -20,
                    left: -10,
                    child: Text(
                      rank.toString(),
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -5,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Category Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    categoryName.toLowerCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Views
                Row(
                  children: [
                    const Icon(Icons.visibility_rounded, color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _formatViews(views),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
