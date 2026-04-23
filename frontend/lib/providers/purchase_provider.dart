import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

/// Holds the set of book IDs the logged-in user has purchased.
final purchaseProvider = StateNotifierProvider<PurchaseNotifier, Set<int>>((ref) {
  return PurchaseNotifier(ref.read(apiClientProvider));
});

class PurchaseNotifier extends StateNotifier<Set<int>> {
  final ApiClient _apiClient;

  PurchaseNotifier(this._apiClient) : super({}) {
    fetchPurchasedBooks();
  }

  Future<void> fetchPurchasedBooks() async {
    try {
      final response = await _apiClient.dio.get('core/purchases/');
      final dynamic data = response.data;
      // Handle paginated or plain list
      final List rawList = data is Map ? (data['results'] ?? []) : data as List;
      final ids = rawList
          .where((p) => p['status'] == 'COMPLETED')
          .map<int>((p) => p['book'] as int)
          .toSet();
      state = ids;
    } catch (_) {
      // Keep empty set if request fails — user just won't see owned books
    }
  }

  bool isOwned(int bookId) => state.contains(bookId);
}
