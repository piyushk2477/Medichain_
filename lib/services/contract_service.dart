import 'api_client.dart';

/// Maps the Solidity `ActionType` enum (GRANTED=0, REVOKED=1, VIEWED=2, DOWNLOADED=3).
enum OnChainAction { granted, revoked, viewed, downloaded }

OnChainAction _actionFromString(String s) {
  switch (s) {
    case 'revoked':
      return OnChainAction.revoked;
    case 'viewed':
      return OnChainAction.viewed;
    case 'downloaded':
      return OnChainAction.downloaded;
    case 'granted':
    default:
      return OnChainAction.granted;
  }
}

/// One entry from the on-chain access log for a medical record.
class AccessLogEntry {
  final String doctorAddress; // checksummed EIP-55, includes 0x
  final String patientAddress; // checksummed EIP-55, includes 0x
  final String recordIdHex; // 0x + 64 hex chars
  final OnChainAction action;
  final DateTime timestamp;
  final int blockNumber;

  const AccessLogEntry({
    required this.doctorAddress,
    required this.patientAddress,
    required this.recordIdHex,
    required this.action,
    required this.timestamp,
    required this.blockNumber,
  });

  String get actionLabel {
    switch (action) {
      case OnChainAction.granted:
        return 'Access Granted';
      case OnChainAction.revoked:
        return 'Access Revoked';
      case OnChainAction.viewed:
        return 'Record Viewed';
      case OnChainAction.downloaded:
        return 'Record Downloaded';
    }
  }

  factory AccessLogEntry.fromJson(Map<String, dynamic> j) => AccessLogEntry(
        doctorAddress: (j['doctorAddress'] ?? '') as String,
        patientAddress: (j['patientAddress'] ?? '') as String,
        recordIdHex: (j['recordIdHex'] ?? '') as String,
        action: _actionFromString((j['action'] ?? 'granted') as String),
        timestamp: DateTime.tryParse((j['timestamp'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        blockNumber: (j['blockNumber'] as num?)?.toInt() ?? 0,
      );

  @override
  String toString() =>
      'AccessLogEntry(action: $actionLabel, doctor: $doctorAddress, '
      'at: $timestamp, block: $blockNumber)';
}

/// Thin client over the backend's blockchain endpoints. All signing and RPC
/// now happen server-side with the user's server-custodied wallet.
class ContractService {
  static final ApiClient _api = ApiClient.instance;

  /// Fetch the full chronological on-chain access log for [recordUuid].
  /// Returns an empty list on error.
  static Future<List<AccessLogEntry>> getAccessLog(String recordUuid) async {
    try {
      final res = await _api.get('/api/blockchain/access-log', query: {
        'recordUuid': recordUuid,
      });
      return (res as List)
          .map((e) => AccessLogEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns true if [doctorAddress] currently has valid access to [recordUuid].
  static Future<bool> hasAccess({
    required String doctorAddress,
    required String recordUuid,
  }) async {
    try {
      final res = await _api.get('/api/blockchain/has-access', query: {
        'doctorAddress': doctorAddress,
        'recordUuid': recordUuid,
      });
      return res['hasAccess'] == true;
    } catch (_) {
      return false;
    }
  }

  /// All doctor wallet addresses ever granted access to [recordUuid].
  static Future<List<String>> getDoctorsWithAccess(String recordUuid) async {
    try {
      final res = await _api.get('/api/blockchain/doctors-with-access', query: {
        'recordUuid': recordUuid,
      });
      return (res as List).map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }

  /// Doctor retrieves the AES key string stored on-chain for [recordUuid].
  static Future<String?> getEncryptedKey(String recordUuid) async {
    try {
      final res = await _api.get('/api/blockchain/encrypted-key', query: {
        'recordUuid': recordUuid,
      });
      return res['encryptedKey'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Doctor logs that they viewed a record. Best-effort.
  static Future<void> logView(String recordUuid) async {
    try {
      await _api.post('/api/blockchain/log-view', body: {
        'recordUuid': recordUuid,
      });
    } catch (_) {
      // Audit-log failures must never break the main UX flow.
    }
  }

  /// Doctor logs that they downloaded a record. Best-effort.
  static Future<void> logDownload(String recordUuid) async {
    try {
      await _api.post('/api/blockchain/log-download', body: {
        'recordUuid': recordUuid,
      });
    } catch (_) {}
  }
}
