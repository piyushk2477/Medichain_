import 'api_client.dart';
import 'records_service.dart';

/// Patient → doctor record sharing. The backend performs the DB upsert AND the
/// best-effort on-chain grant/revoke, so this is now a thin client.
class SharingService {
  static final ApiClient _api = ApiClient.instance;

  /// Share the given record IDs with the given doctor. [expiresAt] is an
  /// optional wall-clock cutoff (null = no expiry). Returns the number shared.
  static Future<int> shareRecords({
    required List<String> recordIds,
    required String doctorId,
    DateTime? expiresAt,
  }) async {
    if (recordIds.isEmpty) return 0;
    final res = await _api.post('/api/sharing/share', body: {
      'recordIds': recordIds,
      'doctorId': doctorId,
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
    });
    return (res['count'] as num?)?.toInt() ?? recordIds.length;
  }

  /// Revoke a single share (soft-delete + on-chain revoke, server-side).
  static Future<void> revokeShare({
    required String recordId,
    required String doctorId,
  }) async {
    await _api.post('/api/sharing/revoke', body: {
      'recordId': recordId,
      'doctorId': doctorId,
    });
  }

  /// IDs of records the patient has already shared with this doctor.
  static Future<Set<String>> sharedRecordIdsFor(String doctorId) async {
    final res = await _api.get('/api/sharing/with-doctor', query: {
      'doctorId': doctorId,
    });
    return (res as List).map((e) => e as String).toSet();
  }

  /// Records that have been shared *with* the currently-logged-in doctor,
  /// optionally scoped to a single patient. Expired shares are filtered
  /// server-side.
  static Future<List<SharedRecord>> recordsSharedWithMe({
    String? patientId,
  }) async {
    final res = await _api.get('/api/sharing/with-me', query: {
      if (patientId != null) 'patientId': patientId,
    });
    return (res as List)
        .map((r) => SharedRecord.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }
}

/// Wraps a `shared_records` row joined to the underlying medical_records row.
class SharedRecord {
  final String shareId;
  final DateTime? sharedAt;
  final DateTime? expiresAt;
  final String patientId;
  final MedicalRecord record;

  SharedRecord({
    required this.shareId,
    required this.sharedAt,
    required this.expiresAt,
    required this.patientId,
    required this.record,
  });

  factory SharedRecord.fromMap(Map<String, dynamic> m) {
    return SharedRecord(
      shareId: m['id'] as String,
      sharedAt: m['shared_at'] == null
          ? null
          : DateTime.tryParse(m['shared_at'] as String),
      expiresAt: m['expires_at'] == null
          ? null
          : DateTime.tryParse(m['expires_at'] as String),
      patientId: m['patient_id'] as String,
      record: MedicalRecord.fromMap(
          (m['record'] as Map).cast<String, dynamic>()),
    );
  }
}
