// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

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

void checkAndSwitchToSecureOrigin() {
  try {
    if (html.window.location.hostname == '0.0.0.0') {
      final current = html.window.location.href;
      final target = current.replaceFirst('//0.0.0.0', '//localhost');
      html.window.location.replace(target);
    }
  } catch (_) {}
}

Future<WebGeoResult> getBrowserCoordinates() async {
  // If running on 0.0.0.0, Chrome strictly rejects geolocation with PERMISSION_DENIED.
  // Switch to localhost so Chrome presents the native location permission prompt.
  if (html.window.location.hostname == '0.0.0.0') {
    try {
      final current = html.window.location.href;
      final target = current.replaceFirst('//0.0.0.0', '//localhost');
      html.window.location.replace(target);
      return const WebGeoResult(
        errorMessage: 'Switching to http://localhost:8080 to enable location permissions...',
      );
    } catch (_) {}
  }

  try {
    final geo = html.window.navigator.geolocation;
    final pos = await geo.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 12),
    );

    final coords = pos.coords;
    if (coords != null &&
        coords.latitude != null &&
        coords.longitude != null) {
      return WebGeoResult(
        latitude: coords.latitude!.toDouble(),
        longitude: coords.longitude!.toDouble(),
      );
    }
  } catch (e) {
    // If browser GPS permission was denied or failed, fall back to network IP geolocation
    try {
      final bdcUrl = 'https://api.bigdatacloud.net/data/reverse-geocode-client';
      final responseText = await html.HttpRequest.getString(bdcUrl).timeout(
        const Duration(seconds: 4),
      );
      final data = jsonDecode(responseText) as Map<String, dynamic>;
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return WebGeoResult(
          latitude: lat,
          longitude: lng,
          errorMessage: 'Located via network IP (browser GPS was disabled or denied).',
        );
      }
    } catch (_) {}

    String message =
        'Location permission was denied. Please allow location access in your browser.';
    bool isDenied = false;
    if (e is html.PositionError) {
      if (e.code == html.PositionError.PERMISSION_DENIED) {
        message =
            'Browser location permission was denied. Please click the permissions icon in your browser address bar to allow location access.';
        isDenied = true;
      } else if (e.code == html.PositionError.POSITION_UNAVAILABLE) {
        message = 'GPS position is currently unavailable.';
      } else if (e.code == html.PositionError.TIMEOUT) {
        message = 'Location request timed out. Please tap your location on the map.';
      }
    }
    return WebGeoResult(errorMessage: message, isPermissionDenied: isDenied);
  }

  return const WebGeoResult(
    errorMessage: 'Unable to read coordinates from browser GPS.',
  );
}

void openMapUrl(String url) {
  html.window.open(url, '_blank');
}

Future<GeocodeResult> fetchReverseGeocode(double lat, double lng) async {
  // 1. Try Nominatim (matches OSM tiles)
  try {
    final url =
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng';
    final responseText = await html.HttpRequest.getString(url).timeout(
      const Duration(seconds: 4),
    );
    final data = jsonDecode(responseText) as Map<String, dynamic>;
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
  } catch (_) {}

  // 2. Fallback to BigDataCloud client-side reverse geocoding API
  try {
    final bdcUrl =
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=en';
    final responseText = await html.HttpRequest.getString(bdcUrl).timeout(
      const Duration(seconds: 4),
    );
    final data = jsonDecode(responseText) as Map<String, dynamic>;
    final locality = data['locality'] as String? ?? '';
    final city = data['city'] as String? ?? '';
    final state = data['principalSubdivision'] as String? ?? '';
    final parts =
        [locality, city, state].where((s) => s.isNotEmpty).toSet().toList();
    if (parts.isNotEmpty) {
      final primary = locality.isNotEmpty
          ? locality
          : (city.isNotEmpty ? city : parts.first);
      final full = parts.join(', ');
      return GeocodeResult(
        displayName: full,
        primaryName: primary,
        locality: city.isNotEmpty && city != primary ? city : state,
        isSuccess: true,
      );
    }
  } catch (_) {}

  return const GeocodeResult.unavailable();
}
