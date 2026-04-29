import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

class PlatformSettings {
  final String appTheme;
  final bool maintenanceMode;
  final String? globalAnnouncement;

  PlatformSettings({
    required this.appTheme,
    required this.maintenanceMode,
    this.globalAnnouncement,
  });

  factory PlatformSettings.fromJson(Map<String, dynamic> json) {
    return PlatformSettings(
      appTheme: json['app_theme'] ?? 'default',
      maintenanceMode: json['maintenance_mode'] ?? false,
      globalAnnouncement: json['global_announcement'],
    );
  }
}

final platformSettingsProvider = StateNotifierProvider<PlatformSettingsNotifier, PlatformSettings?>((ref) {
  return PlatformSettingsNotifier(ref.read(apiClientProvider));
});

class PlatformSettingsNotifier extends StateNotifier<PlatformSettings?> {
  final ApiClient _apiClient;

  PlatformSettingsNotifier(this._apiClient) : super(null) {
    fetchSettings();
  }

  Future<void> fetchSettings() async {
    try {
      final response = await _apiClient.dio.get('core/settings/current/');
      state = PlatformSettings.fromJson(response.data);
    } catch (e) {
      print('Error fetching settings: $e');
    }
  }
}
