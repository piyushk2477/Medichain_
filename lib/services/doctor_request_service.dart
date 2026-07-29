import 'api_client.dart';

/// Reads/writes the `doctor_requests` table (patient↔doctor connection
/// requests) via the backend. Replaces the direct Supabase queries the screens
/// used to make; return shapes are unchanged.
class DoctorRequestService {
  static final ApiClient _api = ApiClient.instance;

  // ── Patient side ───────────────────────────────────────────────────────────

  /// The patient's requests as `{ doctor_id, status }` rows.
  static Future<List<Map<String, dynamic>>> myRequests() async {
    final res = await _api.get('/api/doctor-requests/mine');
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// The patient's accepted connections joined to the doctor (limit N).
  static Future<List<Map<String, dynamic>>> myAcceptedDoctors({
    int limit = 5,
  }) async {
    final res = await _api.get('/api/doctor-requests/mine/accepted-doctors',
        query: {'limit': limit});
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// This patient↔doctor connection status ('none' if no request exists).
  static Future<String> statusFor(String doctorId) async {
    final res =
        await _api.get('/api/doctor-requests/status', query: {'doctorId': doctorId});
    return (res['status'] ?? 'none') as String;
  }

  /// Patient requests (or re-requests) a connection with a doctor.
  static Future<void> requestConnection(String doctorId) async {
    await _api.post('/api/doctor-requests', body: {'doctorId': doctorId});
  }

  // ── Doctor side ────────────────────────────────────────────────────────────

  /// Incoming requests for the logged-in doctor, joined to the patient profile.
  static Future<List<Map<String, dynamic>>> incoming({
    String status = 'pending',
  }) async {
    final res =
        await _api.get('/api/doctor-requests/incoming', query: {'status': status});
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// Accepted patients for the logged-in doctor (joined to the patient profile).
  static Future<List<Map<String, dynamic>>> incomingAccepted() async {
    final res = await _api.get('/api/doctor-requests/incoming/accepted');
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// Count of accepted connections for the logged-in doctor.
  static Future<int> incomingAcceptedCount() async {
    final res = await _api.get('/api/doctor-requests/incoming/accepted/count');
    return (res['count'] as num?)?.toInt() ?? 0;
  }

  /// A single request joined to the full patient profile (or null).
  static Future<Map<String, dynamic>?> getById(String id) async {
    final res = await _api.get('/api/doctor-requests/$id');
    return res == null ? null : (res as Map).cast<String, dynamic>();
  }

  /// Set a request's status (accept / reject).
  static Future<void> setStatus(String id, String status) async {
    await _api.patch('/api/doctor-requests/$id', body: {'status': status});
  }
}
