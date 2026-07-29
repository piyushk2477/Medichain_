import 'dart:async';
import 'dart:io';

import 'api_client.dart';

/// Where the orchestrator currently is — drives the progress UI.
enum UploadStage {
  reading,
  encrypting,
  hashing,
  uploading,
  savingMetadata,
  done,
  failed,
}

class UploadProgress {
  final UploadStage stage;
  final String message;
  final double progress; // 0.0 .. 1.0

  /// Populated only when [stage] == done.
  final UploadResult? result;

  /// Populated only when [stage] == failed.
  final String? error;

  const UploadProgress({
    required this.stage,
    required this.message,
    required this.progress,
    this.result,
    this.error,
  });
}

class UploadResult {
  final String recordId; // Supabase row id
  final String cid;
  final String sha256;
  final int sizeBytes;
  UploadResult({
    required this.recordId,
    required this.cid,
    required this.sha256,
    required this.sizeBytes,
  });
}

/// Drives an upload against the backend. The actual encrypt → hash → pin →
/// save pipeline now runs server-side (see backend/routes/records.js); this
/// keeps the same [Stream<UploadProgress>] API the upload screen subscribes to,
/// emitting progress around the single multipart request.
class UploadService {
  static final ApiClient _api = ApiClient.instance;

  static Stream<UploadProgress> uploadFile({
    required File file,
    required String title,
    required String category,
  }) async* {
    try {
      yield const UploadProgress(
        stage: UploadStage.reading,
        message: 'Reading file…',
        progress: 0.1,
      );
      final bytes = await file.readAsBytes();
      final filename = file.path.split(Platform.pathSeparator).last;

      yield const UploadProgress(
        stage: UploadStage.encrypting,
        message: 'Encrypting & uploading securely…',
        progress: 0.35,
      );

      yield const UploadProgress(
        stage: UploadStage.uploading,
        message: 'Uploading to secure storage…',
        progress: 0.6,
      );

      final res = await _api.uploadFile(
        '/api/records/upload',
        bytes: bytes,
        filename: filename,
        fields: {'title': title, 'category': category},
      );

      yield const UploadProgress(
        stage: UploadStage.savingMetadata,
        message: 'Saving record…',
        progress: 0.9,
      );

      yield UploadProgress(
        stage: UploadStage.done,
        message: 'Done',
        progress: 1.0,
        result: UploadResult(
          recordId: res['recordId'] as String,
          cid: (res['cid'] ?? '') as String,
          sha256: (res['sha256'] ?? '') as String,
          sizeBytes: (res['sizeBytes'] as num?)?.toInt() ?? bytes.length,
        ),
      );
    } catch (e) {
      yield UploadProgress(
        stage: UploadStage.failed,
        message: 'Upload failed',
        progress: 0,
        error: e.toString(),
      );
    }
  }
}
