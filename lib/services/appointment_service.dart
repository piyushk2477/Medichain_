import 'package:intl/intl.dart';

import 'api_client.dart';

/// Appointment requests. Same public API as before; every call now goes to the
/// MediChain backend. The confirmation email (Resend) is sent server-side.
class AppointmentService {
  static final ApiClient _api = ApiClient.instance;

  // ── Patient: request appointment ──────────────────────────────────────────

  static Future<void> requestAppointment({
    required String doctorId,
    required DateTime preferredDate,
    required String preferredTime,
    String? notes,
  }) async {
    await _api.post('/api/appointments', body: {
      'doctorId': doctorId,
      'preferredDate': DateFormat('yyyy-MM-dd').format(preferredDate),
      'preferredTime': preferredTime,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  /// Returns true if the patient already has a pending request with this doctor.
  static Future<bool> hasExistingRequest(String doctorId) async {
    final res = await _api.get('/api/appointments/exists', query: {
      'doctorId': doctorId,
    });
    return res['exists'] == true;
  }

  // ── Doctor: get pending requests ──────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final res = await _api.get('/api/appointments/pending');
    return (res as List).cast<Map<String, dynamic>>();
  }

  // Convenience: just get count for badge.
  static Future<int> getPendingCount() async {
    try {
      final res = await _api.get('/api/appointments/pending/count');
      return (res['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Doctor: confirm appointment ───────────────────────────────────────────

  static Future<void> confirmAppointment({
    required String requestId,
    required String patientEmail,
    required String patientName,
    required String doctorName,
    required String? hospital,
    required DateTime confirmedDate,
    required String confirmedTime,
  }) async {
    await _api.post('/api/appointments/$requestId/confirm', body: {
      'patientEmail': patientEmail,
      'patientName': patientName,
      'doctorName': doctorName,
      'hospital': hospital ?? 'the clinic',
      'confirmedDate': DateFormat('yyyy-MM-dd').format(confirmedDate),
      'confirmedTime': confirmedTime,
    });
  }

  // ── Doctor: decline request ───────────────────────────────────────────────

  static Future<void> declineAppointment(String requestId) async {
    await _api.delete('/api/appointments/$requestId');
  }
}
