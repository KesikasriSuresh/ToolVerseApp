// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

int _viewCounter = 0;

/// Opens the live webcam / camera app in the browser or laptop.
/// Streams live video feed into a viewfinder dialog and captures high-resolution photo on shutter.
Future<Uint8List?> captureLiveCameraPhoto(BuildContext context) async {
  return showDialog<Uint8List?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _LiveWebcamDialog(),
  );
}

class _LiveWebcamDialog extends StatefulWidget {
  const _LiveWebcamDialog();

  @override
  State<_LiveWebcamDialog> createState() => _LiveWebcamDialogState();
}

class _LiveWebcamDialogState extends State<_LiveWebcamDialog> {
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  String? _viewType;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFlashing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        setState(() {
          _errorMessage =
              'Camera is not supported on this browser or requires an HTTPS / localhost connection.';
          _isLoading = false;
        });
        return;
      }

      html.MediaStream stream;
      try {
        // Try environment camera first (back camera on mobile / laptops)
        stream = await mediaDevices.getUserMedia({
          'video': {
            'facingMode': 'environment',
            'width': {'ideal': 1920},
            'height': {'ideal': 1080},
          },
          'audio': false,
        });
      } catch (_) {
        // Fallback to any default camera / laptop webcam
        stream = await mediaDevices.getUserMedia({
          'video': true,
          'audio': false,
        });
      }

      _mediaStream = stream;

      final viewId = 'toolverse-webcam-${++_viewCounter}';
      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..srcObject = stream
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.backgroundColor = '#080B14';

      _videoElement = video;
      _viewType = viewId;

      ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) => video);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to access camera. Please allow camera permissions in your browser: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _snapPhoto() {
    if (_videoElement == null) return;

    final video = _videoElement!;
    final width = video.videoWidth > 0 ? video.videoWidth : 1280;
    final height = video.videoHeight > 0 ? video.videoHeight : 720;

    // Trigger flash animation
    setState(() => _isFlashing = true);

    Timer(const Duration(milliseconds: 140), () {
      try {
        final canvas = html.CanvasElement(width: width, height: height);
        final ctx = canvas.context2D;
        ctx.drawImage(video, 0, 0);

        final dataUrl = canvas.toDataUrl('image/jpeg', 0.92);
        final commaIdx = dataUrl.indexOf(',');
        final base64Str =
            commaIdx != -1 ? dataUrl.substring(commaIdx + 1) : dataUrl;
        final bytes = base64Decode(base64Str);

        _stopCamera();
        if (mounted) {
          Navigator.of(context).pop(bytes);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isFlashing = false;
            _errorMessage = 'Failed to take photo snapshot: $e';
          });
        }
      }
    });
  }

  void _stopCamera() {
    try {
      _mediaStream?.getTracks().forEach((track) {
        track.stop();
      });
      _mediaStream = null;
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1120),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x2AFFFFFF), width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF131929),
                  border: Border(bottom: BorderSide(color: Color(0x2AFFFFFF))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 18, color: Color(0xFF080B14)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Camera Viewfinder',
                            style: TextStyle(
                              color: Color(0xFFEDF2FF),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.circle,
                                  size: 8, color: Color(0xFF10F7A0)),
                              SizedBox(width: 5),
                              Text(
                                'Live feed active · Align item inside frame',
                                style: TextStyle(
                                  color: Color(0xFF5A6A8A),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _stopCamera();
                        Navigator.of(context).pop(null);
                      },
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF5A6A8A)),
                    ),
                  ],
                ),
              ),

              // Viewfinder Video Area
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isLoading)
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Color(0xFF00D4FF)),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Opening device camera…',
                              style: TextStyle(
                                  color: Color(0xFFB8C4E0), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    else if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_off_rounded,
                                  color: Color(0xFFFF4B6E), size: 48),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFFB8C4E0),
                                    fontSize: 13,
                                    height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _initCamera,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00D4FF),
                                  foregroundColor: const Color(0xFF080B14),
                                ),
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_viewType != null)
                      HtmlElementView(viewType: _viewType!),

                    // Viewfinder corner reticles overlay
                    if (!_isLoading && _errorMessage == null)
                      IgnorePointer(
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF00D4FF)
                                  .withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),

                    // Camera Flash Effect
                    if (_isFlashing)
                      Container(
                        color: Colors.white,
                      ),
                  ],
                ),
              ),

              // Bottom Shutter Controls
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF131929),
                  border: Border(top: BorderSide(color: Color(0x2AFFFFFF))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        _stopCamera();
                        Navigator.of(context).pop(null);
                      },
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF5A6A8A))),
                    ),

                    // Big Circular Shutter Button
                    GestureDetector(
                      onTap: (!_isLoading && _errorMessage == null)
                          ? _snapPhoto
                          : null,
                      child: Container(
                        width: 68,
                        height: 68,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00D4FF),
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D4FF)
                                  .withValues(alpha: 0.4),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF00D4FF), Color(0xFF10F7A0)],
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Color(0xFF080B14),
                            size: 28,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 60), // Balance the cancel button
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
