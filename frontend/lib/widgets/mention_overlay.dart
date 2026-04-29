import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mention_provider.dart';

/// Glassmorphic dropdown that shows @mention suggestions.
/// Place this in a Stack above the TextField, positioned dynamically.
class MentionOverlay extends ConsumerWidget {
  /// Called when the user selects a suggestion.
  /// (id, displayLabel)
  final void Function(String id, String label) onMentionSelected;

  const MentionOverlay({super.key, required this.onMentionSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mentionProvider);

    if (!state.isVisible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  const Text('🔍',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(
                    'Mention "@${state.query}"',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => ref.read(mentionProvider.notifier).hide(),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Divider(
                height: 1, color: Color(0xFF2A2A3E)),

            // Loading indicator
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              )
            else if (!state.hasResults)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No matches found',
                  style:
                      TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    // ── Users ──────────────────────────────────────
                    if (state.users.isNotEmpty) ...[
                      _SectionLabel(label: '👤 People'),
                      ...state.users.map((u) => _UserRow(
                            user: u,
                            onTap: () =>
                                onMentionSelected(u.id.toString(), '@${u.username}'),
                          )),
                    ],

                    // ── Books ──────────────────────────────────────
                    if (state.books.isNotEmpty) ...[
                      _SectionLabel(label: '📖 Books'),
                      ...state.books.map((b) => _BookRow(
                            book: b,
                            onTap: () =>
                                onMentionSelected(b.id.toString(), '@[${b.title}]'),
                          )),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6C63FF),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── User row ──────────────────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  final MentionUser user;
  final VoidCallback onTap;
  const _UserRow({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: const Color(0xFF6C63FF).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF6C63FF).withOpacity(0.25),
              backgroundImage: user.avatar != null
                  ? NetworkImage(user.avatar!)
                  : null,
              child: user.avatar == null
                  ? Text(
                      user.username.isNotEmpty
                          ? user.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '@${user.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'User',
                style: TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Book row ──────────────────────────────────────────────────────────────────

class _BookRow extends StatelessWidget {
  final MentionBook book;
  final VoidCallback onTap;
  const _BookRow({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: const Color(0xFFFFD700).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: book.cover != null
                  ? Image.network(book.cover!,
                      width: 28,
                      height: 38,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _bookPlaceholder())
                  : _bookPlaceholder(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Book',
                style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookPlaceholder() => Container(
        width: 28,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.book_rounded,
            color: Color(0xFFFFD700), size: 16),
      );
}
