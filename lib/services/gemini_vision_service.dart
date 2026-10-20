import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _prefKey = 'gemini_api_key_override';
  static const String _defaultApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-preview:generateContent';

  static Future<String?> getSavedApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_prefKey);
      if (key != null && key.trim().isNotEmpty) {
        return key.trim();
      }
    } catch (_) {}
    return _defaultApiKey;
  }

  static Future<void> saveApiKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, key.trim());
    } catch (_) {}
  }

  static Future<void> clearApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {}
  }

  /// Compares the baseline listing image with the newly captured return image.
  static Future<GeminiVisionResult> inspectToolReturn({
    required Uint8List? listingImageBytes,
    required String? listingImageUrl,
    required Uint8List returnImageBytes,
    required String toolName,
    required int depositAmount,
    String? explicitApiKey,
  }) async {
    final apiKey = explicitApiKey ?? await getSavedApiKey();

    // Prepare listing image bytes — with 10s timeout
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

    // If no API key configured, return clear error — no fake scores
    if (apiKey == null || apiKey.isEmpty) {
      return GeminiVisionResult(
        success: false,
        isSameItem: false,
        matchPercentage: 0.0,
        defectsCount: 0,
        surfaceIntegrity: 0.0,
        defectsSummary: 'AI inspection unavailable — Gemini API key not configured.',
        spokenVerdict:
            'AI inspection could not run because the Gemini API key is not configured. Please set up your API key in settings.',
        depositApproved: false,
        isRealAi: false,
        errorMessage: 'No Gemini API key. Go to Settings → Configure Gemini API Key.',
      );
    }

    if (baselineBytes == null || baselineBytes.isEmpty) {
      return GeminiVisionResult(
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
    // Call real Google Gemini 3.1 Flash Lite Vision
    try {
      final listingMime = _detectMimeType(baselineBytes);
      final returnMime = _detectMimeType(returnImageBytes);
      debugPrint('[GeminiVision] Listing: ${baselineBytes.length} bytes ($listingMime), Return: ${returnImageBytes.length} bytes ($returnMime)');

      final b64Listing = base64Encode(baselineBytes);
      final b64Return  = base64Encode(returnImageBytes);

      final prompt = '''
You are the ToolVerse AI Return Condition Inspector for a tool sharing marketplace.
Analyze and compare the two provided images:
- Image 1: The original baseline listing photo of the tool ('$toolName') when listed by the owner.
- Image 2: The returned '$toolName' captured with the camera right now at return.

Perform rigorous visual comparison:
1. Is Image 2 the same tool/item as Image 1? (true/false)
CRITICAL RULE: If Image 2 shows a completely different tool, an unrelated object, a human face/body, room, or animal, you MUST set isSameItem to false, matchPercentage MUST be under 15.0, and depositApproved to false.
2. Carefully inspect the surface, casing, chuck, trigger, power cord/battery, blades, and finish.
   Check for any new cracks, deep scratches, scorch marks, broken guards, or missing accessories.
3. Compute an honest condition match percentage (0% to 100%):
   - 93% to 99%: Same tool in excellent/clean condition with standard gentle handling.
   - 70% to 92%: Same tool with minor cosmetic dust/scuffs that don't affect function.
   - 30% to 69%: Severe damage, broken components, or missing parts.
   - < 15%: Totally different object, wrong item, or ruined tool.
4. Count the number of new defects/scratches detected (0 if pristine).
5. Calculate surface integrity percentage (e.g. 98.4%).
6. Formulate a 1-sentence spoken verdict suitable for text-to-speech that clearly states whether the item matched and whether the security deposit of ₹$depositAmount is authorized.

Return strictly valid JSON matching this schema:
{
  "isSameItem": true,
  "matchPercentage": 96.8,
  "defectsCount": 0,
  "surfaceIntegrity": 98.2,
  "defectsSummary": "No structural damage or new scratches found",
  "spokenVerdict": "ToolVerse AI condition check complete. The returned $toolName matches 96.8% of the original listing photo. Zero structural defects detected. Security deposit of rupees $depositAmount is authorized for full refund.",
  "depositApproved": true
}
''';

      final requestBody = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': listingMime,
                  'data': b64Listing,
                }
              },
              {
                'inline_data': {
                  'mime_type': returnMime,
                  'data': b64Return,
                }
              },
            ]
          }
        ],
        'generationConfig': {
          'response_mime_type': 'application/json',
          'temperature': 0.1,
        },
      });

      final uri = Uri.parse('$_geminiEndpoint?key=$apiKey');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => throw Exception(
                'Gemini API timed out after 25 seconds. Check your internet connection.'),
          );

      if (response.statusCode != 200) {
        debugPrint('[GeminiVision] API Error ${response.statusCode}: ${response.body}');
        return GeminiVisionResult(
          success: false,
          isSameItem: false,
          matchPercentage: 0.0,
          defectsCount: 0,
          surfaceIntegrity: 0.0,
          defectsSummary: 'AI inspection failed — Gemini API error ${response.statusCode}.',
          spokenVerdict:
              'AI inspection failed due to a Gemini API error. Please check your API key and try again.',
          depositApproved: false,
          isRealAi: false,
          errorMessage:
              'Gemini API returned status ${response.statusCode}. Check your API key.',
        );
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = jsonResponse['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('No response candidates from Gemini Vision');
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      final rawText = parts?.first?['text'] as String? ?? '{}';

      final parsed = jsonDecode(rawText) as Map<String, dynamic>;

      final isSame = parsed['isSameItem'] as bool? ?? false;
      final matchPct = (parsed['matchPercentage'] as num?)?.toDouble() ?? 0.0;
      final defects = (parsed['defectsCount'] as num?)?.toInt() ?? 0;
      final surface = (parsed['surfaceIntegrity'] as num?)?.toDouble() ?? 0.0;
      final summary = parsed['defectsSummary'] as String? ?? 'Inspection data unavailable';
      final spoken = parsed['spokenVerdict'] as String? ??
          'ToolVerse AI condition check complete. The returned $toolName matches ${matchPct.toStringAsFixed(1)} percent of the original listing photo.';
      // Enforce deposit logic client-side too
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
      debugPrint('[GeminiVision] Error during vision check: $e');
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

  /// Detects MIME type from byte signatures
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
