import 'api_client.dart';
import 'auth_storage.dart';

/// Profile model matching the backend's profile JSON.
class UserProfile {
  final String name;
  final String? profilePicture;
  final String? shortDescription;
  final List<String> growthAreas;
  final String? mainGoal;
  final String? dailyAvailableTime;
  final bool setupCompleted;

  UserProfile({
    required this.name,
    this.profilePicture,
    this.shortDescription,
    required this.growthAreas,
    this.mainGoal,
    this.dailyAvailableTime,
    required this.setupCompleted,
  });

  /// Maps the backend's snake_case profile JSON to camelCase fields, with
  /// sensible defaults for anything missing (empty name, empty growth-area
  /// list, setup not completed) so a partial payload can never crash the UI.
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? '',
    profilePicture: json['profile_picture'] as String?,
    shortDescription: json['short_description'] as String?,
    growthAreas: List<String>.from(json['growth_areas'] ?? const []),
    mainGoal: json['main_goal'] as String?,
    dailyAvailableTime: json['daily_available_time'] as String?,
    setupCompleted: json['setup_completed'] as bool? ?? false,
  );
}

/// Talks to /api/profile for the authenticated user.
class ProfileService {
  ProfileService({ApiClient? client, AuthStorage? storage})
    : _client = client ?? ApiClient(),
      _storage = storage ?? AuthStorage();

  final ApiClient _client;
  final AuthStorage _storage;

  /// Reads the profile. Like every endpoint, the payload is wrapped, so the
  /// actual object always lives under the 'profile' key of the response.
  Future<UserProfile> getProfile() async {
    final token = await _storage.getToken();
    final res = await _client.get('/profile', token: token);
    return UserProfile.fromJson(res['profile'] as Map<String, dynamic>);
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> fields) async {
    final token = await _storage.getToken();
    final res = await _client.put('/profile', body: fields, token: token);
    return UserProfile.fromJson(res['profile'] as Map<String, dynamic>);
  }

  /// Returns today's reflection if the user saved one (Phase 10), or null
  /// when today has none. The query date is the device's local calendar day
  /// (yyyy-MM-dd), matching how the backend groups reflections per day.
  Future<Map<String, dynamic>?> getTodayReflection() async {
    final token = await _storage.getToken();
    final res = await _client.get(
      '/reflections?date=${DateTime.now().toIso8601String().substring(0, 10)}',
      token: token,
    );
    final list = res['reflections'] as List;
    return list.isEmpty ? null : list.first as Map<String, dynamic>;
  }
}
