import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class GeminiVisionResult {
  final bool success;
  final bool isSameItem;
  final double matchPercentage;
  final int defectsCount;
  final double surfaceIntegrity;
  final String defectsSummary;
  final String spokenVerdict;
  final bool depositApproved;
  final String? errorMessage;
  final bool isRealAi;

  const GeminiVisionResult({
    required this.success,
    required this.isSameItem,
    required this.matchPercentage,
    required this.defectsCount,
    required this.surfaceIntegrity,
    required this.defectsSummary,
    required this.spokenVerdict,
    required this.depositApproved,
    this.errorMessage,
    required this.isRealAi,
  });

  String get matchPercentageString => '${matchPercentage.toStringAsFixed(1)}%';
}

class GeminiVisionService {
  // Legacy SharedPrefs key — kept so we can clear stale keys on startup.
  static const String _prefKey = 'gemini_api_key_override';

  /// Clear any stale client-side Gemini API key stored from previous versions.
  /// The key is now managed server-side only.
  static Future<void> clearLegacyKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {}
  }

  // Legacy key accessors — retained so existing settings dialog still compiles.
  static Future<String?> getSavedApiKey() async => null;
  static Future<void> saveApiKey(String key) async {}
  static Future<void> clearApiKey() async {
    await clearLegacyKey();
  }

  /// Compares the baseline listing image with the newly captured return image
  /// by routing the request through the ToolVerse backend.
  /// The Gemini API key is stored server-side only (.env) — never on the client.
  static Future<GeminiVisionResult> inspectToolReturn({
    required Uint8List? listingImageBytes,
    required String? listingImageUrl,
    required Uint8List returnImageBytes,
    required String toolName,
    required int depositAmount,
    String? explicitApiKey, // ignored — kept for API compatibility
  }) async {
    // Download listing image if not already in memory
    Uint8List? baselineBytes = listingImageBytes;
    if ((baselineBytes == null || baselineBytes.isEmpty) &&
        listingImageUrl != null &&
        listingImageUrl.isNotEmpty) {
      try {
        final resp = await http
            .get(Uri.parse(listingImageUrl))
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          baselineBytes = resp.bodyBytes;
        }
      } catch (e) {
        debugPrint('[GeminiVision] Failed to download listing image: $e');
      }
    }

    if (baselineBytes == null || baselineBytes.isEmpty) {
      return const GeminiVisionResult(
        success: false,
        isSameItem: false,
        matchPercentage: 0.0,
        defectsCount: 0,
        surfaceIntegrity: 0.0,
        defectsSummary: 'AI inspection unavailable — original listing photo could not be loaded.',
        spokenVerdict:
            'AI inspection could not run because the original listing photo is unavailable.',
        depositApproved: false,
        isRealAi: false,
        errorMessage: 'Original listing photo could not be fetched. Please retry.',
      );
    }

    final listingMime = _detectMimeType(baselineBytes);
    final returnMime = _detectMimeType(returnImageBytes);
    debugPrint(
        '[GeminiVision] Listing: ${baselineBytes.length} bytes ($listingMime), Return: ${returnImageBytes.length} bytes ($returnMime)');

    // Route through backend — API key lives in server .env
    try {
      final apiService = ApiService();
      final baseUrl = apiService.baseUrl;

      final requestBody = jsonEncode({
        'listingImageB64': base64Encode(baselineBytes),
        'returnImageB64': base64Encode(returnImageBytes),
        'listingMime': listingMime,
        'returnMime': returnMime,
        'toolName': toolName,
        'depositAmount': depositAmount,
      });

      final headers = <String, String>{'Content-Type': 'application/json'};
      final token = apiService.authToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('$baseUrl/api/ai/inspect');
      debugPrint('[GeminiVision] Calling backend: $uri');

      final response = await http
          .post(uri, headers: headers, body: requestBody)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw Exception(
                'Backend AI inspection timed out after 60 seconds.'),
          );

      if (response.statusCode != 200) {
        debugPrint('[GeminiVision] Backend error ${response.statusCode}: ${response.body}');
        // Parse a clean message from the backend error body
        String cleanError = 'AI inspection failed (${response.statusCode}).';
        try {
          final errBody = jsonDecode(response.body) as Map<String, dynamic>;
          final detail = errBody['detail'] as String? ?? '';
          if (detail.isNotEmpty) {
            // Strip the "GEMINI_HTTP_XXX: " prefix if present
            cleanError = detail.replaceFirst(RegExp(r'^GEMINI_HTTP_\d+:\s*'), '');
          }
        } catch (_) {}
        return GeminiVisionResult(
          success: false,
          isSameItem: false,
          matchPercentage: 0.0,
          defectsCount: 0,
          surfaceIntegrity: 0.0,
          defectsSummary: 'AI inspection failed — $cleanError',
          spokenVerdict:
              'AI inspection failed due to a server error. Please try again.',
          depositApproved: false,
          isRealAi: false,
          errorMessage: cleanError,
        );
      }

      final parsed = jsonDecode(response.body) as Map<String, dynamic>;

      final isSame = parsed['isSameItem'] as bool? ?? false;
      final matchPct = (parsed['matchPercentage'] as num?)?.toDouble() ?? 0.0;
      final defects = (parsed['defectsCount'] as num?)?.toInt() ?? 0;
      final surface = (parsed['surfaceIntegrity'] as num?)?.toDouble() ?? 0.0;
      final summary =
          parsed['defectsSummary'] as String? ?? 'Inspection data unavailable';
      final spoken = parsed['spokenVerdict'] as String? ??
          'ToolVerse AI condition check complete. The returned $toolName matches ${matchPct.toStringAsFixed(1)} percent of the original listing photo.';
      // Enforce deposit logic client-side as double-check
      final depositOk = isSame && matchPct >= 75.0;

      return GeminiVisionResult(
        success: true,
        isSameItem: isSame,
        matchPercentage: matchPct,
        defectsCount: defects,
        surfaceIntegrity: surface,
        defectsSummary: summary,
        spokenVerdict: spoken,
        depositApproved: depositOk,
        isRealAi: true,
      );
    } catch (e) {
      debugPrint('[GeminiVision] Error during backend inspection call: $e');
      return GeminiVisionResult(
        success: false,
        isSameItem: false,
        matchPercentage: 0.0,
        defectsCount: 0,
        surfaceIntegrity: 0.0,
        defectsSummary: 'AI inspection failed — connection error.',
        spokenVerdict: 'ToolVerse AI inspection failed due to a connection error. Please retry.',
        depositApproved: false,
        isRealAi: false,
        errorMessage: 'Connection error: $e',
      );
    }
  }

  /// Detects MIME type from byte magic bytes
  static String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}
