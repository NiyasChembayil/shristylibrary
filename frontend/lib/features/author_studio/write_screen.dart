import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'dart:async';
import '../../providers/author_provider.dart';
import '../../providers/book_provider.dart';
import '../../models/book_model.dart';

class WriteScreen extends ConsumerStatefulWidget {
  final int bookId;
  final int? chapterId;

  const WriteScreen({super.key, required this.bookId, this.chapterId});

  @override
  ConsumerState<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends ConsumerState<WriteScreen> {
  quill.QuillController? _controller;
  Timer? _autoSaveTimer;
  bool _isSaving = false;
  ChapterModel? _currentChapter;

  @override
  void initState() {
    super.initState();
    _loadChapter();
  }

  Future<void> _loadChapter() async {
    final book = await ref.read(bookProvider.notifier).fetchBookDetails(widget.bookId);
    if (book != null && book.chapters.isNotEmpty) {
      _currentChapter = widget.chapterId != null 
          ? book.chapters.firstWhere((c) => c.id == widget.chapterId)
          : book.chapters.first;
      
      final delta = HtmlToDelta().convert(_currentChapter!.content);
      setState(() {
        _controller = quill.QuillController(
          document: quill.Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      });

      _controller!.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveContent();
    });
  }

  Future<void> _saveContent() async {
    if (_controller == null || _currentChapter == null || _isSaving) return;

    setState(() => _isSaving = true);
    final content = _controller!.document.toDelta().toJson().toString(); // Simplified for now
    
    final success = await ref.read(authorStudioProvider.notifier).updateChapter(
      _currentChapter!.id, 
      content,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-saved'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(_currentChapter?.title ?? 'Editing', style: const TextStyle(fontSize: 16)),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 15),
                child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.done_all, color: Color(0xFF10B981)),
            onPressed: _saveContent,
          ),
        ],
      ),
      body: Column(
        children: [
          quill.QuillToolbar.simple(
            configurations: quill.QuillSimpleToolbarConfigurations(
              controller: _controller!,
              sharedConfigurations: const quill.QuillSharedConfigurations(
                locale: Locale('en'),
              ),
              showSearchButton: false,
              showLink: false,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showListCheck: false,
              multiRowsDisplay: false,
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF0F0F1E),
              child: quill.QuillEditor.basic(
                configurations: quill.QuillEditorConfigurations(
                  controller: _controller!,
                  readOnly: false,
                  sharedConfigurations: const quill.QuillSharedConfigurations(
                    locale: Locale('en'),
                  ),
                  placeholder: 'Once upon a time...',
                  padding: EdgeInsets.zero,
                  autoFocus: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
