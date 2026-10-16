import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WebGeoResult {
  final double? latitude;
  final double? longitude;
  final String? errorMessage;
  final bool isPermissionDenied;

  const WebGeoResult({
    this.latitude,
    this.longitude,
    this.errorMessage,
    this.isPermissionDenied = false,
  });
}

class GeocodeResult {
  final String displayName;
  final String primaryName;
  final String? locality;
  final bool isSuccess;

  const GeocodeResult({
    required this.displayName,
    required this.primaryName,
    this.locality,
    this.isSuccess = true,
  });

  const GeocodeResult.unavailable()
      : displayName = 'Address unavailable',
        primaryName = 'Address unavailable',
        locality = null,
        isSuccess = false;
}

Future<WebGeoResult> getBrowserCoordinates() async {
  return const WebGeoResult(
    errorMessage:
        'Browser GPS is only available on Web. Please select your location on the map.',
  );
}

void openMapUrl(String url) {
  // Fallback for non-web environments (tests and VM)
}

void checkAndSwitchToSecureOrigin() {
  // Non-web no-op
}

Future<GeocodeResult> fetchReverseGeocode(double lat, double lng) async {
  // 1. Try Nominatim (matches OSM tiles)
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    final request = await client.getUrl(Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng'));
    request.headers.set('User-Agent', 'ToolVerseApp/1.0 (Flutter)');
    request.headers.set('Accept', 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final displayName = data['display_name'] as String? ?? '';
      final address = (data['address'] as Map<String, dynamic>?) ?? {};
      final primary = (data['name'] as String?)?.isNotEmpty == true
          ? data['name'] as String
          : (address['amenity'] ??
              address['building'] ??
              address['shop'] ??
              address['road'] ??
              address['suburb'] ??
              address['neighbourhood'] ??
              address['village'] ??
              address['city'] ??
              displayName);
      final locality = address['suburb'] ??
          address['neighbourhood'] ??
          address['village'] ??
          address['city'] ??
          address['state'];
      if (displayName.isNotEmpty) {
        return GeocodeResult(
          displayName: displayName,
          primaryName: primary.toString(),
          locality: locality?.toString(),
          isSuccess: true,
        );
      }
    }
  } catch (_) {}

  // 2. Secondary fallback for tests / VM
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    final request = await client.getUrl(Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=en'));
    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final locality = data['locality'] as String? ?? '';
      final city = data['city'] as String? ?? '';
      final state = data['principalSubdivision'] as String? ?? '';
      final parts =
          [locality, city, state].where((s) => s.isNotEmpty).toSet().toList();
      if (parts.isNotEmpty) {
        final primary = locality.isNotEmpty
            ? locality
            : (city.isNotEmpty ? city : parts.first);
        return GeocodeResult(
          displayName: parts.join(', '),
          primaryName: primary,
          locality: city.isNotEmpty && city != primary ? city : state,
          isSuccess: true,
        );
      }
    }
  } catch (_) {}

  return const GeocodeResult.unavailable();
}
