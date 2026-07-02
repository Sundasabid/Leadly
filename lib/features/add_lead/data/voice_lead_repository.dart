import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceLeadException implements Exception {
  final String errorCode;
  final String message;
  const VoiceLeadException(this.errorCode, this.message);
}

class VoiceLeadRepository {
  final SupabaseClient _client;

  VoiceLeadRepository(this._client);

  Future<Map<String, dynamic>> extractLead({
    required String audioBase64,
    required String mimeType,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'extract-lead',
        body: {'audio': audioBase64, 'mimeType': mimeType},
      );
      return response.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      final details = e.details;
      final code =
          (details is Map ? details['error'] as String? : null) ?? 'unknown';
      final msg = (details is Map ? details['message'] as String? : null) ??
          'An unexpected error occurred.';
      throw VoiceLeadException(code, msg);
    }
  }
}

final voiceLeadRepositoryProvider = Provider<VoiceLeadRepository>((ref) {
  return VoiceLeadRepository(Supabase.instance.client);
});
