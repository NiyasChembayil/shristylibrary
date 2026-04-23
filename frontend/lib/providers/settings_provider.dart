import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import 'auth_provider.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});

class SettingsState {
  final bool isPrivateAccount;
  final bool notifyNewFollower;
  final bool notifyLikes;
  final bool notifyComments;
  final bool notifyNewBooks;
  final bool audioAutoPlay;
  final bool audioDownloadWifiOnly;
  final bool audioBackgroundPlay;
  final double playbackSpeed;
  final double fontSize;
  final String readerTheme;
  final bool isLoading;

  SettingsState({
    this.isPrivateAccount = false,
    this.notifyNewFollower = true,
    this.notifyLikes = true,
    this.notifyComments = true,
    this.notifyNewBooks = true,
    this.audioAutoPlay = false,
    this.audioDownloadWifiOnly = true,
    this.audioBackgroundPlay = true,
    this.playbackSpeed = 1.0,
    this.fontSize = 16.0,
    this.readerTheme = 'Dark',
    this.isLoading = false,
  });

  SettingsState copyWith({
    bool? isPrivateAccount,
    bool? notifyNewFollower,
    bool? notifyLikes,
    bool? notifyComments,
    bool? notifyNewBooks,
    bool? audioAutoPlay,
    bool? audioDownloadWifiOnly,
    bool? audioBackgroundPlay,
    double? playbackSpeed,
    double? fontSize,
    String? readerTheme,
    bool? isLoading,
  }) {
    return SettingsState(
      isPrivateAccount: isPrivateAccount ?? this.isPrivateAccount,
      notifyNewFollower: notifyNewFollower ?? this.notifyNewFollower,
      notifyLikes: notifyLikes ?? this.notifyLikes,
      notifyComments: notifyComments ?? this.notifyComments,
      notifyNewBooks: notifyNewBooks ?? this.notifyNewBooks,
      audioAutoPlay: audioAutoPlay ?? this.audioAutoPlay,
      audioDownloadWifiOnly: audioDownloadWifiOnly ?? this.audioDownloadWifiOnly,
      audioBackgroundPlay: audioBackgroundPlay ?? this.audioBackgroundPlay,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      fontSize: fontSize ?? this.fontSize,
      readerTheme: readerTheme ?? this.readerTheme,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;
  
  SettingsNotifier(this._ref) : super(SettingsState()) {
    _init();
  }

  void _init() {
    // Listen to auth changes to sync profile settings
    _ref.listen(authProvider, (previous, next) {
      if (next.profile != null) {
        final p = next.profile!;
        state = state.copyWith(
          isPrivateAccount: p.isPrivate,
          notifyNewFollower: p.notifyNewFollower,
          notifyLikes: p.notifyLikes,
          notifyComments: p.notifyComments,
          notifyNewBooks: p.notifyNewBooks,
          fontSize: p.fontSize,
          readerTheme: p.readerTheme,
          playbackSpeed: p.playbackSpeed,
        );
      }
    }, fireImmediately: true);
    
    _loadLocalSettings();
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      audioAutoPlay: prefs.getBool('audioAutoPlay') ?? false,
      audioDownloadWifiOnly: prefs.getBool('audioDownloadWifiOnly') ?? true,
      audioBackgroundPlay: prefs.getBool('audioBackgroundPlay') ?? true,
    );
  }

  Future<bool> updateSetting(String key, dynamic value) async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Update local storage for immediate persistence of UI-only settings
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }

      // Sync with backend if it's a profile-level setting
      final profileKeys = {
        'isPrivateAccount': 'is_private',
        'notifyNewFollower': 'notify_new_follower',
        'notifyLikes': 'notify_likes',
        'notifyComments': 'notify_comments',
        'notifyNewBooks': 'notify_new_books',
        'fontSize': 'font_size',
        'readerTheme': 'reader_theme',
        'playbackSpeed': 'playback_speed',
      };

      if (profileKeys.containsKey(key)) {
        final backendKey = profileKeys[key]!;
        await _ref.read(apiClientProvider).dio.patch('accounts/profile/me/', data: {
          backendKey: value,
        });
        // Refresh profile in AuthProvider to keep everything in sync
        _ref.read(authProvider.notifier).refreshProfile();
      }

      // Update local state
      _updateLocalState(key, value);
      return true;
    } catch (e) {
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void _updateLocalState(String key, dynamic value) {
    switch (key) {
      case 'isPrivateAccount': state = state.copyWith(isPrivateAccount: value); break;
      case 'notifyNewFollower': state = state.copyWith(notifyNewFollower: value); break;
      case 'notifyLikes': state = state.copyWith(notifyLikes: value); break;
      case 'notifyComments': state = state.copyWith(notifyComments: value); break;
      case 'notifyNewBooks': state = state.copyWith(notifyNewBooks: value); break;
      case 'audioAutoPlay': state = state.copyWith(audioAutoPlay: value); break;
      case 'audioDownloadWifiOnly': state = state.copyWith(audioDownloadWifiOnly: value); break;
      case 'audioBackgroundPlay': state = state.copyWith(audioBackgroundPlay: value); break;
      case 'playbackSpeed': state = state.copyWith(playbackSpeed: value); break;
      case 'fontSize': state = state.copyWith(fontSize: value); break;
      case 'readerTheme': state = state.copyWith(readerTheme: value); break;
    }
  }
}
