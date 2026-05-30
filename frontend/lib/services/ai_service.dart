import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_suggestion.dart';
import 'image_preprocessor.dart';

class AiServiceException implements Exception {
  final String message;
  final String code;
  final Object? cause;

  const AiServiceException(this.message, {required this.code, this.cause});

  bool get isOffline => code == 'offline';
  bool get isTimeout => code == 'timeout';
  bool get isRateLimited => code == 'rate_limit';
  bool get isRetryable =>
      code == 'timeout' ||
      code == 'offline' ||
      code == 'rate_limit' ||
      code == 'server_error';

  @override
  String toString() => 'AiServiceException($code): $message';
}

class AiService {
  static const int _maxBytes = 10 * 1024 * 1024; // 10 MB
  static const Duration _timeout = Duration(seconds: 60);
  static const String _functionName = 'ai-identify';

  final SupabaseClient _client;

  AiService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<AiSuggestion> identify(File imageFile) async {
    if (!await imageFile.exists()) {
      throw const AiServiceException(
        'File foto tidak ditemukan.',
        code: 'file_missing',
      );
    }

    final length = await imageFile.length();
    if (length > _maxBytes) {
      throw const AiServiceException(
        'Ukuran foto melebihi 10MB. Coba foto yang lebih kecil.',
        code: 'too_large',
      );
    }

    final rawBytes = await imageFile.readAsBytes();
    final enhancedBytes = ImagePreprocessor.enhance(rawBytes);
    final base64Image = base64Encode(enhancedBytes);
    final mediaType = 'image/jpeg';

    try {
      final response = await _client.functions
          .invoke(
            _functionName,
            body: {'image_base64': base64Image, 'media_type': mediaType},
          )
          .timeout(_timeout);

      final status = response.status;

      if (status == 429) {
        throw const AiServiceException(
          'Server AI sedang sibuk. Coba lagi sebentar.',
          code: 'rate_limit',
        );
      }
      if (status >= 500) {
        throw AiServiceException(
          'Server AI bermasalah (HTTP $status).',
          code: 'server_error',
        );
      }
      if (status >= 400) {
        throw AiServiceException(
          'Permintaan AI ditolak (HTTP $status).',
          code: 'bad_request',
        );
      }

      final data = response.data;
      if (data is! Map) {
        throw const AiServiceException(
          'Respons AI tidak valid.',
          code: 'invalid_response',
        );
      }

      return AiSuggestion.fromJson(Map<String, dynamic>.from(data));
    } on AiServiceException {
      rethrow;
    } on TimeoutException catch (e) {
      throw AiServiceException(
        'Permintaan AI melebihi 60 detik.',
        code: 'timeout',
        cause: e,
      );
    } on SocketException catch (e) {
      throw AiServiceException(
        'Tidak ada koneksi internet. Isi form secara manual.',
        code: 'offline',
        cause: e,
      );
    } on FunctionException catch (e) {
      final status = e.status;
      if (status == 429) {
        throw AiServiceException(
          'Server AI sedang sibuk. Coba lagi sebentar.',
          code: 'rate_limit',
          cause: e,
        );
      }
      if (status >= 500) {
        throw AiServiceException(
          'Server AI bermasalah (HTTP $status).',
          code: 'server_error',
          cause: e,
        );
      }
      throw AiServiceException(
        'Gagal memanggil AI: ${e.details ?? e.toString()}',
        code: 'function_error',
        cause: e,
      );
    } catch (e) {
      throw AiServiceException(
        'Terjadi kesalahan tak terduga: $e',
        code: 'unknown',
        cause: e,
      );
    }
  }


}
