import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/book_model.dart';

class ReaderScreen extends StatefulWidget {
  final int bookId;
  final String title;
  final List<ChapterModel> chapters;
  final int initialChapterIndex;

  const ReaderScreen({
    super.key,
    required this.bookId,
    required this.title,
    required this.chapters,
    this.initialChapterIndex = 0,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late PageController _pageController;
  int _currentChapterIndex = 0;
  double _fontSize = 18.0;
  Color _backgroundColor = const Color(0xFF0F0F1E);
  Color _textColor = Colors.white70;
  bool _isLoadingPrefs = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialChapterIndex;
    _loadPreferences();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fontSize = prefs.getDouble('reader_font_size') ?? 18.0;
      final themeIndex = prefs.getInt('reader_theme_index') ?? 0;
      if (themeIndex == 1) {
        _backgroundColor = Colors.white;
        _textColor = Colors.black87;
      } else if (themeIndex == 2) {
        _backgroundColor = const Color(0xFFF4ECD8);
        _textColor = const Color(0xFF5D4037);
      }
      
      // Load bookmark for this specific book
      final bookmark = prefs.getInt('bookmark_${widget.bookId}');
      if (bookmark != null && bookmark < widget.chapters.length) {
        _currentChapterIndex = bookmark;
      }
      
      _pageController = PageController(initialPage: _currentChapterIndex);
      _isLoadingPrefs = false;
    });
    
    // Attempt to restore scroll position after a short delay for the current chapter
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _scrollController.hasClients) {
        final scrollPos = prefs.getDouble('bookmark_scroll_${widget.bookId}_$_currentChapterIndex');
        if (scrollPos != null) {
          _scrollController.jumpTo(scrollPos);
        }
      }
    });

    _scrollController.addListener(() {
      // Save scroll position as you read
      if (_scrollController.hasClients) {
        prefs.setDouble('bookmark_scroll_${widget.bookId}_$_currentChapterIndex', _scrollController.offset);
      }
    });
  }

  Future<void> _saveBookmark(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bookmark_${widget.bookId}', index);
  }

  Future<void> _saveThemePreference(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reader_theme_index', index);
  }

  Future<void> _saveFontSizePreference(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_size', size);
  }

  void _changeTheme(Color bg, Color text, int index) {
    setState(() {
      _backgroundColor = bg;
      _textColor = text;
    });
    _saveThemePreference(index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPrefs) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.chapters.isNotEmpty 
              ? widget.chapters[_currentChapterIndex].title 
              : widget.title, 
          style: TextStyle(color: _textColor, fontSize: 16)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(
            onPressed: () => _showSettingsSheet(context),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: widget.chapters.isEmpty
          ? Center(child: Text("No content available", style: TextStyle(color: _textColor)))
          : PageView.builder(
              controller: _pageController,
              itemCount: widget.chapters.length,
              onPageChanged: (index) {
                setState(() => _currentChapterIndex = index);
                _saveBookmark(index);
              },
              itemBuilder: (context, index) {
                return SingleChildScrollView(
                  controller: index == _currentChapterIndex ? _scrollController : null,
                  padding: const EdgeInsets.all(25.0),
                  child: Text(
                    widget.chapters[index].content,
                    style: GoogleFonts.inter(
                      fontSize: _fontSize,
                      color: _textColor,
                      height: 1.8,
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(30),
              height: 350,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Appearance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Font Size', style: TextStyle(fontSize: 16)),
                      Row(
                        children: [
                          IconButton(onPressed: () {
                            setState(() => _fontSize--);
                            _saveFontSizePreference(_fontSize);
                          }, icon: const Icon(Icons.remove_circle_outline)),
                          Text('${_fontSize.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(onPressed: () {
                            setState(() => _fontSize++);
                            _saveFontSizePreference(_fontSize);
                          }, icon: const Icon(Icons.add_circle_outline)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text('Theme', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 15),
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _themeCircle(const Color(0xFF0F0F1E), Colors.white70, 'Dark', 0),
                      _themeCircle(Colors.white, Colors.black87, 'Light', 1),
                      _themeCircle(const Color(0xFFF4ECD8), const Color(0xFF5D4037), 'Sepia', 2),
                    ],
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _themeCircle(Color bg, Color text, String label, int index) {
    bool isSelected = _backgroundColor == bg;
    return GestureDetector(
      onTap: () {
        _changeTheme(bg, text, index);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? const Color(0xFF6C63FF) : Colors.grey.withValues(alpha: 0.3), width: 3),
            ),
          ),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(color: isSelected ? const Color(0xFF6C63FF) : Colors.grey)),
        ],
      ),
    );
  }
}
