import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

class CategoryModel {
  final String name;
  final String slug;
  final int priority;
  final bool isBoosted;

  CategoryModel({
    required this.name,
    required this.slug,
    required this.priority,
    required this.isBoosted,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      name: json['name'],
      slug: json['slug'],
      priority: json['priority'] ?? 0,
      isBoosted: json['is_boosted'] ?? false,
    );
  }
}

final categoryProvider = StateNotifierProvider<CategoryNotifier, List<CategoryModel>>((ref) {
  return CategoryNotifier();
});

class CategoryNotifier extends StateNotifier<List<CategoryModel>> {
  CategoryNotifier() : super([]) {
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    try {
      final List response = await ApiClient.get('/core/categories/');
      final categories = response.map((j) => CategoryModel.fromJson(j)).toList();
      
      // Sort by boosted then priority
      categories.sort((a, b) {
        if (a.isBoosted != b.isBoosted) {
          return a.isBoosted ? -1 : 1;
        }
        return b.priority.compareTo(a.priority);
      });
      
      state = categories;
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }
}
