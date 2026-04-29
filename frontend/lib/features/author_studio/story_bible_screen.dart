import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'dart:async';
import '../../providers/author_provider.dart';

class StoryBibleScreen extends ConsumerStatefulWidget {
  final int bookId;
  final String bookTitle;

  const StoryBibleScreen({super.key, required this.bookId, required this.bookTitle});

  @override
  ConsumerState<StoryBibleScreen> createState() => _StoryBibleScreenState();
}

class _StoryBibleScreenState extends ConsumerState<StoryBibleScreen> {
  quill.QuillController? _controller;
  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadBible();
  }

  Future<void> _loadBible() async {
    final content = await ref.read(authorStudioProvider.notifier).fetchStoryBible(widget.bookId);
    if (mounted) {
      if (content != null) {
        final delta = HtmlToDelta().convert(content);
        setState(() {
          _controller = quill.QuillController(
            document: quill.Document.fromDelta(delta),
            selection: const TextSelection.collapsed(offset: 0),
          );
          _isLoading = false;
        });
        _controller!.addListener(_onTextChanged);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () => _saveBible());
  }

  Future<void> _saveBible() async {
    if (_controller == null || _isSaving) return;
    setState(() => _isSaving = true);
    
    final content = _controller!.document.toDelta().toJson().toString();
    final success = await ref.read(authorStudioProvider.notifier).updateStoryBible(widget.bookId, content);
    
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bible Auto-saved'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Story Bible', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.bookTitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 15), child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))),
          IconButton(
            icon: const Icon(Icons.save_rounded, color: Color(0xFF6C63FF)),
            onPressed: _saveBible,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _controller == null
              ? const Center(child: Text('Could not load Story Bible', style: TextStyle(color: Colors.white54)))
              : Column(
                  children: [
                    quill.QuillToolbar.simple(
                      configurations: quill.QuillSimpleToolbarConfigurations(
                        controller: _controller!,
                        sharedConfigurations: const quill.QuillSharedConfigurations(locale: Locale('en')),
                        showSearchButton: false,
                        showLink: false,
                        multiRowsDisplay: false,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: quill.QuillEditor.basic(
                          configurations: quill.QuillEditorConfigurations(
                            controller: _controller!,
                            readOnly: false,
                            placeholder: 'Characters, World History, Plot Notes...',
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
