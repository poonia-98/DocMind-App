// lib/features/chat/camera_scan_screen.dart
//
// FIXED VERSION – proper camera view + manual/auto capture modes
//
// Features:
// - Manual mode: User taps to capture
// - Auto mode: Detects document edges + stillness + clarity → auto-captures
//
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;

import '../../shared/theme/app_colors.dart';

enum CaptureMode { manual, auto }

class CameraScanScreen extends StatefulWidget {
  final void Function(String?) onTextExtracted;

  const CameraScanScreen({
    super.key,
    required this.onTextExtracted,
  });

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen>
    with WidgetsBindingObserver {
  // ── camera state ──────────────────────────────────────────────────────────
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _cameraReady = false;

  // ── capture modes ─────────────────────────────────────────────────────────
  CaptureMode _captureMode = CaptureMode.manual;
  bool _isCapturing = false;
  bool _isSending = false;
  String? _errorMessage;

  // ── auto-capture state ────────────────────────────────────────────────────
  Timer? _autoCaptureTicker;
  bool _isDocumentDetected = false;
  bool _isStill = false;
  double _currentBlur = 0.0;
  int _stillFrameCount = 0;
  Uint8List? _lastFrame;

  // ── thresholds ────────────────────────────────────────────────────────────
  static const int _stillFramesRequired = 3; // 3 stable frames
  static const double _blurThreshold = 100.0; // Lower = blurrier
  static const double _motionThreshold = 15.0; // Pixel difference threshold

  // ── lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCaptureTicker?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _stopAutoCapture();
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_cameras[_selectedCameraIndex]);
    }
  }

  // ── camera init ───────────────────────────────────────────────────────────
  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera available on this device.');
        return;
      }
      await _initCamera(_cameras[_selectedCameraIndex]);
    } catch (e) {
      setState(() => _errorMessage = 'Camera init error: $e');
    }
  }

  Future<void> _initCamera(CameraDescription camera) async {
    _controller?.dispose();

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _cameraReady = true);
        if (_captureMode == CaptureMode.auto) {
          _startAutoCapture();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to open camera: $e');
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _stopAutoCapture();
    setState(() => _cameraReady = false);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCamera(_cameras[_selectedCameraIndex]);
  }

  // ── mode switching ────────────────────────────────────────────────────────
  void _toggleCaptureMode() {
    setState(() {
      _captureMode = _captureMode == CaptureMode.manual
          ? CaptureMode.auto
          : CaptureMode.manual;
      
      if (_captureMode == CaptureMode.auto) {
        _startAutoCapture();
      } else {
        _stopAutoCapture();
      }
    });
  }

  // ── auto-capture logic ────────────────────────────────────────────────────
  void _startAutoCapture() {
    _stopAutoCapture();
    
    _autoCaptureTicker = Timer.periodic(
      const Duration(milliseconds: 500), // Check every 500ms
      (_) => _checkAutoCapture(),
    );
  }

  void _stopAutoCapture() {
    _autoCaptureTicker?.cancel();
    _autoCaptureTicker = null;
    _stillFrameCount = 0;
    _lastFrame = null;
    if (mounted) {
      setState(() {
        _isDocumentDetected = false;
        _isStill = false;
      });
    }
  }

  Future<void> _checkAutoCapture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isCapturing || _isSending) return;

    try {
      final XFile image = await _controller!.takePicture();
      final Uint8List imageBytes = await image.readAsBytes();

      // 1. Check for motion (compare with last frame)
      final bool isStillNow = await _checkStillness(imageBytes);
      
      // 2. Check for blur (image clarity)
      final double blurScore = await _calculateBlur(imageBytes);
      final bool isClear = blurScore > _blurThreshold;

      if (mounted) {
        setState(() {
          _isStill = isStillNow;
          _currentBlur = blurScore;
          _isDocumentDetected = isClear; // Simplified: clear image = document detected
        });
      }

      // 3. Auto-capture if conditions met
      if (isStillNow && isClear) {
        _stillFrameCount++;
        
        if (_stillFrameCount >= _stillFramesRequired) {
          // All conditions met → auto-capture!
          _stillFrameCount = 0;
          await _captureAndScan(imageBytes: imageBytes);
        }
      } else {
        _stillFrameCount = 0;
      }

      _lastFrame = imageBytes;

    } catch (e) {
      print('Auto-capture check error: $e');
    }
  }

  Future<bool> _checkStillness(Uint8List currentFrame) async {
    if (_lastFrame == null) return false;

    try {
      final img.Image? current = img.decodeImage(currentFrame);
      final img.Image? last = img.decodeImage(_lastFrame!);

      if (current == null || last == null) return false;

      // Resize for faster comparison
      final img.Image currentSmall = img.copyResize(current, width: 100);
      final img.Image lastSmall = img.copyResize(last, width: 100);

      // Calculate pixel difference
      int diffSum = 0;
      int pixelCount = currentSmall.width * currentSmall.height;

      for (int y = 0; y < currentSmall.height; y++) {
        for (int x = 0; x < currentSmall.width; x++) {
          final currentPixel = currentSmall.getPixel(x, y);
          final lastPixel = lastSmall.getPixel(x, y);

          final rDiff = (currentPixel.r - lastPixel.r).abs();
          final gDiff = (currentPixel.g - lastPixel.g).abs();
          final bDiff = (currentPixel.b - lastPixel.b).abs();

          diffSum += (rDiff + gDiff + bDiff) ~/ 3;
        }
      }

      final double avgDiff = diffSum / pixelCount;
      return avgDiff < _motionThreshold;

    } catch (e) {
      print('Stillness check error: $e');
      return false;
    }
  }

  Future<double> _calculateBlur(Uint8List imageBytes) async {
    try {
      final img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return 0.0;

      // Resize for faster processing
      final img.Image small = img.copyResize(image, width: 200);

      // Convert to grayscale
      final img.Image gray = img.grayscale(small);

      // Calculate Laplacian variance (blur detection)
      int variance = 0;
      int count = 0;

      for (int y = 1; y < gray.height - 1; y++) {
        for (int x = 1; x < gray.width - 1; x++) {
          final center = gray.getPixel(x, y).r.toInt();
          final top = gray.getPixel(x, y - 1).r.toInt();
          final bottom = gray.getPixel(x, y + 1).r.toInt();
          final left = gray.getPixel(x - 1, y).r.toInt();
          final right = gray.getPixel(x + 1, y).r.toInt();

          final laplacian = (4 * center - top - bottom - left - right).abs();
          variance += laplacian * laplacian;
          count++;
        }
      }

      return count > 0 ? variance / count : 0.0;

    } catch (e) {
      print('Blur calculation error: $e');
      return 0.0;
    }
  }

  // ── manual capture ────────────────────────────────────────────────────────
  Future<void> _captureAndScan({Uint8List? imageBytes}) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isCapturing || _isSending) return;

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      Uint8List finalImageBytes;

      if (imageBytes != null) {
        // Auto-capture: use provided bytes
        finalImageBytes = imageBytes;
      } else {
        // Manual capture: take new photo
        final XFile xFile = await _controller!.takePicture();
        finalImageBytes = await xFile.readAsBytes();
      }

      setState(() {
        _isCapturing = false;
        _isSending = true;
      });

      // Upload to Supabase Storage
      await _uploadScanToSupabase(finalImageBytes);

      // Close screen
      if (mounted) {
        widget.onTextExtracted(null);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isSending = false;
          _errorMessage = 'Scan failed: $e';
        });
      }
    }
  }

  Future<void> _uploadScanToSupabase(Uint8List imageBytes) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final String filePath =
        'scans/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage.from('documents').uploadBinary(filePath, imageBytes);

    // Create document entry (triggers backend OCR + Gemini)
    await supabase.from('documents').insert({
      'user_id': user.id,
      'title': 'Camera Scan ${DateTime.now().toString().substring(0, 16)}',
      'file_type': 'jpg',
      'file_size': imageBytes.length,
      'status': 'processing',
      'processed': false,
      'source': 'camera',
    });

    // Create job
    await supabase.from('jobs').insert({
      'user_id': user.id,
      'type': 'OCR',
      'status': 'queued',
      'payload': {'path': filePath, 'filename': 'camera_scan.jpg'},
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null || !_cameraReady || _controller == null) {
      return _buildErrorScaffold();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildCameraBody(),
    );
  }

  Widget _buildCameraBody() {
    return Stack(
      children: [
        // ✅ FIXED: Proper camera preview without zoom
        Positioned.fill(
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
        ),

        // Overlays
        _buildGuideOverlay(),
        _buildTopBar(),
        _buildAutoModeIndicators(),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildGuideOverlay() {
    return Center(
      child: IgnorePointer(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.width * 0.85 * 1.41, // A4 ratio
          decoration: BoxDecoration(
            border: Border.all(
              color: _isDocumentDetected
                  ? Colors.greenAccent.withOpacity(0.8)
                  : Colors.white.withOpacity(0.45),
              width: _isDocumentDetected ? 3 : 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              _captureMode == CaptureMode.auto
                  ? (_isDocumentDetected
                      ? (_isStill ? 'Hold still...' : 'Keep steady')
                      : 'Align document')
                  : 'Align document here',
              style: TextStyle(
                color: _isDocumentDetected ? Colors.greenAccent : Colors.white70,
                fontSize: 16,
                fontWeight:
                    _isDocumentDetected ? FontWeight.w600 : FontWeight.normal,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const Text(
              'Scan Document',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              onPressed: _switchCamera,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoModeIndicators() {
    if (_captureMode != CaptureMode.auto) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isStill ? Icons.check_circle : Icons.motion_photos_on,
                  color: _isStill ? Colors.greenAccent : Colors.orangeAccent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _isStill ? 'Still' : 'Moving',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _currentBlur > _blurThreshold
                      ? Icons.check_circle
                      : Icons.blur_on,
                  color: _currentBlur > _blurThreshold
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentBlur > _blurThreshold ? 'Clear' : 'Blurry',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final bool busy = _isCapturing || _isSending;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              // Mode toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton('Manual', CaptureMode.manual),
                    _buildModeButton('Auto', CaptureMode.auto),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),

              // Status text
              if (_isSending)
                const Text(
                  'Processing scan…',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                )
              else if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center,
                )
              else if (_captureMode == CaptureMode.auto)
                Text(
                  _isDocumentDetected && _isStill
                      ? 'Auto-capturing in ${_stillFramesRequired - _stillFrameCount}...'
                      : 'Auto mode: Position document',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),

              const SizedBox(height: 16),

              // Capture button (manual only)
              if (_captureMode == CaptureMode.manual)
                Center(
                  child: AnimatedScale(
                    scale: busy ? 0.9 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: GestureDetector(
                      onTap: busy ? null : () => _captureAndScan(),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: busy ? Colors.grey : AppColors.primary,
                            ),
                            child: busy
                                ? const Center(
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                // Auto mode indicator
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isDocumentDetected && _isStill
                            ? Colors.greenAccent
                            : Colors.white,
                        width: 3,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isDocumentDetected && _isStill
                              ? Colors.greenAccent.withOpacity(0.3)
                              : Colors.transparent,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, CaptureMode mode) {
    final isSelected = _captureMode == mode;
    
    return GestureDetector(
      onTap: () => _toggleCaptureMode(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Document')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Camera is not ready',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initCameras,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}