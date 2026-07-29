import 'api_client.dart';

/// Reads/writes `profiles` and `patients` via the backend. Replaces the direct
/// Supabase queries in the profile/edit screens.
class ProfileService {
  static final ApiClient _api = ApiClient.instance;

  /// The caller's full profiles row (or null).
  static Future<Map<String, dynamic>?> myProfile() async {
    final res = await _api.get('/api/profiles/me');
    return res == null ? null : (res as Map).cast<String, dynamic>();
  }

  /// Update the caller's display name (keeps auth metadata in sync server-side).
  static Future<void> updateFullName(String fullName) async {
    await _api.patch('/api/profiles/me', body: {'full_name': fullName});
  }

  /// Counts + name/email for the patient profile screen.
  static Future<Map<String, dynamic>> myStats() async {
    final res = await _api.get('/api/profiles/me/stats');
    return (res as Map).cast<String, dynamic>();
  }

  /// The caller's patients row (or null).
  static Future<Map<String, dynamic>?> myPatient() async {
    final res = await _api.get('/api/patients/me');
    return res == null ? null : (res as Map).cast<String, dynamic>();
  }

  /// Upsert the caller's patients row.
  static Future<void> upsertPatient(Map<String, dynamic> patient) async {
    await _api.put('/api/patients/me', body: patient);
  }
}
