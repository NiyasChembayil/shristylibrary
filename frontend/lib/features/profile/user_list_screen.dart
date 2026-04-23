import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class UserListScreen extends ConsumerStatefulWidget {
  final String title;
  final String endpoint;

  const UserListScreen({
    super.key,
    required this.title,
    required this.endpoint,
  });

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get(widget.endpoint);
      setState(() {
        _users = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load users';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : _users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          Text(
                            'No ${widget.title.toLowerCase()} yet.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final String username = user['username'] ?? 'User';
                        final String? avatarUrl = user['avatar'];

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF1E1E2E),
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null
                                  ? Text(
                                      username[0].toUpperCase(),
                                      style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(
                              username,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white24),
                            onTap: () {
                              // For now, we don't have a way to view other users' profiles 
                              // unless we add a parameter to ProfileScreen.
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
