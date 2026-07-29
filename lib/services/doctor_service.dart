import 'api_client.dart';

/// Reads the `doctors` table via the backend. Replaces the direct
/// `Supabase.instance.client.from('doctors')` queries the screens used to make.
/// Every method returns the same JSON shape the screens already expect
/// (including nested `profiles(full_name)` joins).
class DoctorService {
  static final ApiClient _api = ApiClient.instance;

  /// All doctors (full profile), ordered by name. Optionally filtered by
  /// specialization (ilike).
  static Future<List<Map<String, dynamic>>> listDoctors({
    String? specialization,
  }) async {
    final res = await _api.get('/api/doctors', query: {
      if (specialization != null && specialization.isNotEmpty)
        'specialization': specialization,
    });
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// A small subset of doctors by id (id, name, specialization, hospital_name).
  static Future<List<Map<String, dynamic>>> listByIds(
      List<String> ids) async {
    if (ids.isEmpty) return [];
    final res = await _api.get('/api/doctors', query: {'ids': ids.join(',')});
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// Every doctor's specialization only — for computing per-specialty counts.
  static Future<List<Map<String, dynamic>>> specializations() async {
    final res = await _api.get('/api/doctors/specializations');
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// A single doctor's public profile (or null).
  static Future<Map<String, dynamic>?> getDoctor(String id) async {
    final res = await _api.get('/api/doctors/$id');
    return res == null ? null : (res as Map).cast<String, dynamic>();
  }

  /// The logged-in doctor's own row (or null).
  static Future<Map<String, dynamic>?> getMyDoctorProfile() async {
    final res = await _api.get('/api/doctors/me');
    return res == null ? null : (res as Map).cast<String, dynamic>();
  }

  /// Upsert the logged-in doctor's profile. Mirrors doctor_profile_edit's save
  /// (profiles first, then doctors) — done atomically on the backend.
  static Future<void> upsertMyDoctorProfile({
    required String fullName,
    required Map<String, dynamic> doctor,
  }) async {
    await _api.put('/api/doctors/me', body: {
      'fullName': fullName,
      'doctor': doctor,
    });
  }
}
