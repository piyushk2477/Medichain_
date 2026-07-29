import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

/// One row from the `medical_records` table (shape unchanged).
class MedicalRecord {
  final String id;
  final String patientId;
  final String title;
  final String? category;
  final String? filename;
  final String? mimeType;
  final int? sizeBytes;
  final String cid;
  final String sha256;
  final String encryptedKey;
  final String iv;
  final DateTime? createdAt;

  MedicalRecord({
    required this.id,
    required this.patientId,
    required this.title,
    this.category,
    this.filename,
    this.mimeType,
    this.sizeBytes,
    required this.cid,
    required this.sha256,
    required this.encryptedKey,
    required this.iv,
    this.createdAt,
  });

  factory MedicalRecord.fromMap(Map<String, dynamic> m) {
    return MedicalRecord(
      id: m['id'] as String,
      patientId: m['patient_id'] as String,
      title: (m['title'] ?? 'Untitled') as String,
      category: m['category'] as String?,
      filename: m['filename'] as String?,
      mimeType: m['mime_type'] as String?,
      sizeBytes: (m['file_size_bytes'] as num?)?.toInt(),
      cid: (m['cid'] ?? '') as String,
      sha256: (m['sha256'] ?? '') as String,
      encryptedKey: (m['encrypted_key'] ?? '') as String,
      iv: (m['iv'] ?? '') as String,
      createdAt: m['created_at'] == null
          ? null
          : DateTime.tryParse(m['created_at'] as String),
    );
  }
}

/// Reads medical records via the backend. Encryption/decryption and IPFS all
/// happen server-side now — the app only ever sees plaintext bytes.
class RecordsService {
  static final ApiClient _api = ApiClient.instance;

  /// All records owned by the currently logged-in patient, newest first.
  static Future<List<MedicalRecord>> listMyRecords() async {
    final res = await _api.get('/api/records');
    return (res as List)
        .map((r) => MedicalRecord.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Fetch a single record by id (RLS on the backend blocks records you can't read).
  static Future<MedicalRecord?> getRecord(String id) async {
    final res = await _api.get('/api/records/$id');
    if (res == null) return null;
    return MedicalRecord.fromMap((res as Map).cast<String, dynamic>());
  }

  /// Ask the backend to download from IPFS, verify the hash, decrypt, and
  /// return the raw plaintext bytes.
  static Future<Uint8List> decryptRecord(MedicalRecord r) async {
    return _api.getBytes('/api/records/${r.id}/download');
  }

  /// Decrypts then writes to a temporary file so an external viewer
  /// (PDF reader, gallery) can open it. Returns the local file path.
  static Future<File> decryptToTempFile(MedicalRecord r) async {
    final bytes = await decryptRecord(r);
    final dir = await getTemporaryDirectory();
    final ext = _extensionFor(r);
    final safeName = r.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final path = '${dir.path}/$safeName-${r.id.substring(0, 8)}$ext';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Delete a record's metadata row (the IPFS pin lingers, as before).
  static Future<void> deleteRecord(String id) async {
    await _api.delete('/api/records/$id');
  }

  static String _extensionFor(MedicalRecord r) {
    final fname = (r.filename ?? '').toLowerCase();
    if (fname.endsWith('.pdf')) return '.pdf';
    if (fname.endsWith('.png')) return '.png';
    if (fname.endsWith('.jpg') || fname.endsWith('.jpeg')) return '.jpg';
    final mt = r.mimeType ?? '';
    if (mt.contains('pdf')) return '.pdf';
    if (mt.contains('png')) return '.png';
    if (mt.contains('jpeg') || mt.contains('jpg')) return '.jpg';
    return '.bin';
  }
}
