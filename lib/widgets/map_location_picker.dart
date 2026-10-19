// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'web_location_helper.dart';

/// Encapsulates the selected location and human-readable address.
class LocationResult {
  final double latitude;
  final double longitude;
  final String address;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  @override
  String toString() =>
      'LocationResult(lat: $latitude, lng: $longitude, address: $address)';
}

/// Popular pre-configured societies and neighborhoods for one-tap selection.
class PresetLocation {
  final String name;
  final double latitude;
  final double longitude;

  const PresetLocation(this.name, this.latitude, this.longitude);
}

const List<PresetLocation> kPopularLocations = [
  PresetLocation('Palm Meadows, Block C', 12.9576, 77.7441),
  PresetLocation('Prestige Tech Cloud, Phase 2', 13.1986, 77.7066),
  PresetLocation('Greenwood Residency, Tower 4', 12.9279, 77.6833),
  PresetLocation('Sobha City, Block D', 13.0645, 77.6256),
  PresetLocation('Brigade Gateway, Wing C', 13.0135, 77.5539),
  PresetLocation('Indiranagar 100ft Road', 12.9716, 77.6412),
  PresetLocation('Koramangala 4th Block', 12.9352, 77.6245),
  PresetLocation('HSR Layout Sector 1', 12.9121, 77.6446),
  PresetLocation('Whitefield Main Road', 12.9698, 77.7499),
];

/// A responsive, Google Maps-style interactive map location picker for ToolVerse.
class MapLocationPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const MapLocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  /// Convenient modal opener for both mobile and desktop screens.
  static Future<LocationResult?> show(
    BuildContext context, {
    double? initialLatitude,
    double? initialLongitude,
    String? initialAddress,
  }) {
    return showDialog<LocationResult>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
          child: MapLocationPicker(
            initialLatitude: initialLatitude,
            initialLongitude: initialLongitude,
            initialAddress: initialAddress,
          ),
        ),
      ),
    );
  }

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  // Current coordinates
  late double _latitude;
  late double _longitude;
  int _zoom = 15;

  bool _isLocatingGps = false;
  bool _isGeocoding = false;
  bool _isDraggingPin = false;

  String? _statusMessage;
  bool _statusIsError = false;

  String _resolvedPlaceName = '';
  String _resolvedAddress = '';
  String? _resolvedLocality;

  Timer? _geocodeDebounce;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude ?? 12.9576;
    _longitude = widget.initialLongitude ?? 77.7441;

    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _resolvedPlaceName = widget.initialAddress!;
      _resolvedAddress = widget.initialAddress!;
    } else {
      _resolvedPlaceName = 'Locating your exact position…';
      _resolvedAddress = 'Requesting browser GPS permissions…';
    }

    // Immediately request exact GPS on open if not already set, otherwise reverse geocode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialLatitude == null || widget.initialLongitude == null) {
        _requestCurrentLocation();
      } else {
        _reverseGeocodeCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Reverse Geocoding
  // ---------------------------------------------------------------------------

  Future<void> _reverseGeocodeCurrentLocation() async {
    setState(() {
      _isGeocoding = true;
    });

    final targetLat = _latitude;
    final targetLng = _longitude;

    final result = await fetchReverseGeocode(targetLat, targetLng);
    if (!mounted) return;

    // Check if user has already moved the pin to a different location while fetching
    if ((_latitude - targetLat).abs() > 0.0001 ||
        (_longitude - targetLng).abs() > 0.0001) {
      return;
    }

    setState(() {
      _isGeocoding = false;
      if (result.isSuccess) {
        _resolvedPlaceName = result.primaryName;
        _resolvedAddress = result.displayName;
        _resolvedLocality = result.locality;
        _statusMessage = null;
        _statusIsError = false;
      } else {
        _resolvedPlaceName = 'Address unavailable';
        _resolvedAddress = 'Address unavailable';
        _resolvedLocality = null;
      }
    });
  }

  void _scheduleReverseGeocode() {
    _geocodeDebounce?.cancel();
    setState(() {
      _isGeocoding = true;
    });
    _geocodeDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        _reverseGeocodeCurrentLocation();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Web GPS Geolocation
  // ---------------------------------------------------------------------------

  Future<void> _requestCurrentLocation() async {
    if (_isLocatingGps) return;
    setState(() {
      _isLocatingGps = true;
      _statusMessage = null;
    });

    final res = await getBrowserCoordinates();
    if (!mounted) return;

    if (res.latitude != null && res.longitude != null) {
      final lat = res.latitude!;
      final lng = res.longitude!;

      setState(() {
        _latitude = lat;
        _longitude = lng;
        _isLocatingGps = false;
        _statusMessage = 'GPS position acquired! Retrieving place name…';
        _statusIsError = false;
      });

      await _reverseGeocodeCurrentLocation();
    } else {
      _handleGpsFailure(res.errorMessage ??
          'Location permission was denied or unavailable in your browser.');
    }
  }

  void _handleGpsFailure(String reason) {
    if (!mounted) return;
    setState(() {
      _isLocatingGps = false;
      _statusMessage = reason;
      _statusIsError = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Map Math & Gestures
  // ---------------------------------------------------------------------------

  void _onPanUpdate(DragUpdateDetails details) {
    final double worldSize = 256.0 * math.pow(2, _zoom);
    final double deltaLng = -(details.delta.dx / worldSize) * 360.0;
    final double deltaLat = (details.delta.dy / worldSize) * 180.0;

    setState(() {
      _latitude = (_latitude + deltaLat).clamp(-85.0, 85.0);
      _longitude = ((_longitude + deltaLng + 180.0) % 360.0) - 180.0;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDraggingPin = false);
    _scheduleReverseGeocode();
  }

  void _onMapTap(TapUpDetails details, Size mapSize) {
    final double worldSize = 256.0 * math.pow(2, _zoom);
    final double deltaPxX = details.localPosition.dx - (mapSize.width / 2.0);
    final double deltaPxY = details.localPosition.dy - (mapSize.height / 2.0);

    final double centerWorldX = (_longitude + 180.0) / 360.0 * worldSize;
    final double centerLatRad = _latitude * math.pi / 180.0;
    final double centerWorldY = (1.0 -
            math.log(math.tan(centerLatRad) + 1.0 / math.cos(centerLatRad)) /
                math.pi) /
        2.0 *
        worldSize;

    final double tappedWorldX = centerWorldX + deltaPxX;
    final double tappedWorldY = centerWorldY + deltaPxY;

    final double newLng = ((tappedWorldX / worldSize) * 360.0 - 180.0);
    final double n = math.pi - (2.0 * math.pi * tappedWorldY / worldSize);
    final double newLat =
        (180.0 / math.pi) * math.atan(0.5 * (math.exp(n) - math.exp(-n)));

    setState(() {
      _latitude = newLat.clamp(-85.0, 85.0);
      _longitude = ((newLng + 180.0) % 360.0) - 180.0;
    });

    _scheduleReverseGeocode();
  }

  void _zoomIn() {
    if (_zoom < 18) {
      setState(() => _zoom++);
    }
  }

  void _zoomOut() {
    if (_zoom > 10) {
      setState(() => _zoom--);
    }
  }

  void _confirmSelection() {
    final chosenAddress = _resolvedAddress.isNotEmpty &&
            _resolvedAddress != 'Address unavailable' &&
            _resolvedAddress != 'Retrieving address details…'
        ? _resolvedAddress
        : (_resolvedPlaceName.isNotEmpty &&
                _resolvedPlaceName != 'Address unavailable' &&
                _resolvedPlaceName != 'Resolving location…'
            ? _resolvedPlaceName
            : 'Location (${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)})');

    Navigator.of(context).pop(
      LocationResult(
        latitude: _latitude,
        longitude: _longitude,
        address: chosenAddress,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI Builder
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1224),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x334A7CFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            if (_statusMessage != null) _buildStatusBanner(),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInteractiveMap(),
                    _buildGpsActionBar(),
                    _buildSelectedLocationDisplay(),
                  ],
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF131A33),
        border: Border(bottom: BorderSide(color: Color(0x224A7CFF))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00F5FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.place_rounded,
              color: Color(0xFF00F5FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Map Location',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tap anywhere or drag the map to move the pin',
                  style: TextStyle(
                    color: Color(0xFF8B9CB8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF8B9CB8)),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Cancel',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isErr = _statusIsError;
    final color = isErr ? const Color(0xFFFFBB00) : const Color(0xFF10F7A0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(
            isErr ? Icons.info_outline_rounded : Icons.check_circle_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            color: color,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _statusMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveMap() {
    return Container(
      height: 300,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF080C18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x334A7CFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapSize = Size(constraints.maxWidth, constraints.maxHeight);

          return MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Drag-to-pan & Tap-to-position canvas
                GestureDetector(
                  onPanDown: (_) => setState(() => _isDraggingPin = true),
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  onPanCancel: () => setState(() => _isDraggingPin = false),
                  onTapUp: (details) => _onMapTap(details, mapSize),
                  child: _buildTileGrid(),
                ),

                // Center Pin with dynamic drag-lift animation
                IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.translationValues(
                        0, _isDraggingPin ? -10 : 0, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Place Name floating badge above pin
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          constraints: const BoxConstraints(maxWidth: 240),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0D1224).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isGeocoding
                                  ? const Color(0xFF00F5FF)
                                  : (_resolvedPlaceName == 'Address unavailable'
                                      ? const Color(0xFFFF4B6E)
                                      : const Color(0xFF00F5FF)),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F5FF)
                                    .withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: _isGeocoding
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFF00F5FF)),
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Locating…',
                                      style: TextStyle(
                                        color: Color(0xFF00F5FF),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  _resolvedPlaceName.isNotEmpty
                                      ? _resolvedPlaceName
                                      : '${_latitude.toStringAsFixed(4)}°, ${_longitude.toStringAsFixed(4)}°',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 4),
                        // Glowing pin icon
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF00F5FF),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF00F5FF),
                            size: 40,
                          ),
                        ),
                        // Pulse shadow base
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: _isDraggingPin ? 18 : 14,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black
                                .withValues(alpha: _isDraggingPin ? 0.35 : 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top-right controls: Zoom in, Zoom out, GPS
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      _mapCircleButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Zoom in',
                        onTap: _zoomIn,
                      ),
                      const SizedBox(height: 8),
                      _mapCircleButton(
                        icon: Icons.remove_rounded,
                        tooltip: 'Zoom out',
                        onTap: _zoomOut,
                      ),
                      const SizedBox(height: 8),
                      _mapCircleButton(
                        icon: _isLocatingGps
                            ? Icons.hourglass_top_rounded
                            : Icons.my_location_rounded,
                        tooltip: 'Detect my current GPS location',
                        color: const Color(0xFF10F7A0),
                        onTap: _requestCurrentLocation,
                      ),
                    ],
                  ),
                ),

                // Bottom-left hint overlay
                Positioned(
                  bottom: 10,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x224A7CFF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.touch_app_rounded,
                            size: 12, color: Color(0xFF00F5FF)),
                        SizedBox(width: 4),
                        Text(
                          'Tap or drag anywhere to place pin',
                          style:
                              TextStyle(color: Color(0xFF8B9CB8), fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Renders OpenStreetMap tiles with sub-pixel alignment for smooth panning
  Widget _buildTileGrid() {
    final n = math.pow(2, _zoom);
    final xFloat = (_longitude + 180.0) / 360.0 * n;
    final tileX = xFloat.floor();
    final latRad = _latitude * math.pi / 180.0;
    final yFloat =
        ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
            2.0 *
            n);
    final tileY = yFloat.floor();

    final subTileOffsetX = -(xFloat - (tileX + 0.5)) * 256.0;
    final subTileOffsetY = -(yFloat - (tileY + 0.5)) * 256.0;

    return Container(
      color: const Color(0xFF161F36),
      child: Center(
        child: Transform.translate(
          offset: Offset(subTileOffsetX, subTileOffsetY),
          child: SizedBox(
            width: 768,
            height: 768,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 9,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemBuilder: (ctx, idx) {
                final dx = (idx % 3) - 1;
                final dy = (idx ~/ 3) - 1;
                final currentTileX = tileX + dx;
                final currentTileY = tileY + dy;
                final url =
                    'https://tile.openstreetmap.org/$_zoom/$currentTileX/$currentTileY.png';

                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF18223C),
                      border: Border.all(color: const Color(0x1A4A7CFF)),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.map_outlined,
                        size: 24,
                        color: Color(0x334A7CFF),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGpsActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: _isLocatingGps ? null : _requestCurrentLocation,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF10F7A0).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF10F7A0).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLocatingGps)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10F7A0)),
                  ),
                )
              else
                const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF10F7A0)),
              const SizedBox(width: 8),
              Text(
                _isLocatingGps
                    ? 'Requesting browser GPS permission & locating…'
                    : 'Locate My Exact Position (GPS)',
                style: const TextStyle(
                  color: Color(0xFF10F7A0),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Read-only Google Maps-style location display showing resolved place name & address
  Widget _buildSelectedLocationDisplay() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF131A33),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00F5FF).withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F5FF).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10F7A0).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.pin_drop_rounded,
                    color: Color(0xFF10F7A0),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'SELECTED PICKUP LOCATION',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF8B9CB8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isGeocoding)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF00F5FF)),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF080C18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x334A7CFF)),
                    ),
                    child: Text(
                      '${_latitude.toStringAsFixed(4)}°, ${_longitude.toStringAsFixed(4)}°',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF00F5FF),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Primary Place Name
            Text(
              _isGeocoding
                  ? 'Resolving location name…'
                  : (_resolvedPlaceName.isNotEmpty
                      ? _resolvedPlaceName
                      : 'Address unavailable'),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            // Subtitle / Full Address or Locality
            Text(
              _isGeocoding
                  ? 'Contacting geocoding service…'
                  : (_resolvedAddress.isNotEmpty &&
                          _resolvedAddress != _resolvedPlaceName &&
                          _resolvedAddress != 'Address unavailable'
                      ? _resolvedAddress
                      : (_resolvedLocality ??
                          (_resolvedPlaceName == 'Address unavailable'
                              ? 'Tap or drag on the map to choose another spot'
                              : 'Coordinates: ${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}'))),
              style: const TextStyle(
                color: Color(0xFF8B9CB8),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF131A33),
        border: Border(top: BorderSide(color: Color(0x224A7CFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF8B9CB8), fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _confirmSelection,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F5FF), Color(0xFF7928CA)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F5FF).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isGeocoding)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    else
                      const Icon(Icons.check_rounded,
                          color: Colors.black, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _isGeocoding ? 'Resolving…' : 'Confirm Location',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF0D1224).withValues(alpha: 0.9),
        shape: const CircleBorder(
          side: BorderSide(color: Color(0x334A7CFF)),
        ),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
