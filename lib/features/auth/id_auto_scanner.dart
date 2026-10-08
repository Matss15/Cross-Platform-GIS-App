part of '../../app.dart';

// GCash-style government ID auto-scanner.
//
// The camera preview is analyzed continuously (image stream on Android/iOS,
// small frames read from the <video> element on web). A frame is "ready" when the four card edges
// line up with the on-screen guide, lighting is acceptable, text is sharp and
// the phone is steady. After a few consecutive ready frames the ID is captured
// and cropped automatically, then Gemini runs a quick advisory pre-check so
// obvious non-IDs are rejected before the citizen submits the form.

/// Guide width relative to the preview; height follows the ID-1 card ratio.
const double _idGuideWidthFraction = 0.86;
const double _idCardAspectRatio = 1.586;

// Auto-capture tuning. Pixel values refer to the downsampled analysis frame.
const int _idAnalysisWidth = 200;
const int _idStableFramesRequired = 3;
const Duration _idAnalysisInterval = Duration(milliseconds: 220);
const double _idMinBrightness = 55;
const double _idMaxBrightness = 215;
const double _idMaxGlareFraction = 0.06;
const double _idMinSharpness = 60;
const int _idEdgeGradientThreshold = 14;
const double _idMinEdgeCoverage = 0.55;
const double _idMinEdgeSmoothness = 0.6;
const double _idMaxMotion = 6;
const Duration _idFallbackDelay = Duration(seconds: 15);

/// A scan session that has not captured an ID by then expires and turns the
/// camera off until the citizen taps "Scan ulit".
const int _idScanTimeoutSeconds = 30;

Rect _idGuideRect(double width, double height) {
  var guideWidth = width * _idGuideWidthFraction;
  var guideHeight = guideWidth / _idCardAspectRatio;
  if (guideHeight > height * 0.8) {
    guideHeight = height * 0.8;
    guideWidth = guideHeight * _idCardAspectRatio;
  }
  return Rect.fromCenter(
    center: Offset(width / 2, height / 2),
    width: guideWidth,
    height: guideHeight,
  );
}

class _GrayFrame {
  const _GrayFrame(this.width, this.height, this.pixels);

  final int width;
  final int height;
  final Uint8List pixels;

  double get aspectRatio => width / height;

  int at(int x, int y) => pixels[y * width + x];
}

/// Builds a small grayscale frame, rotated to match what the user sees.
_GrayFrame _grayFrameFromCameraImage(CameraImage image, int rotation) {
  final plane = image.planes.first;
  final bytes = plane.bytes;
  final isBgra = image.format.group == ImageFormatGroup.bgra8888;
  final pixelStride = isBgra ? 4 : (plane.bytesPerPixel ?? 1);
  // Green is the closest single channel to luminance for BGRA frames.
  final channelOffset = isBgra ? 1 : 0;
  final srcWidth = image.width;
  final srcHeight = image.height;
  final rotated = rotation == 90 || rotation == 270;
  final displayWidth = rotated ? srcHeight : srcWidth;
  final displayHeight = rotated ? srcWidth : srcHeight;
  final outWidth = math.min(_idAnalysisWidth, displayWidth);
  final scale = displayWidth / outWidth;
  final outHeight = (displayHeight / scale).floor();
  final out = Uint8List(outWidth * outHeight);

  for (var y = 0; y < outHeight; y++) {
    final dy = (y * scale).floor();
    for (var x = 0; x < outWidth; x++) {
      final dx = (x * scale).floor();
      int sx;
      int sy;
      switch (rotation) {
        case 90:
          sx = dy;
          sy = srcHeight - 1 - dx;
        case 180:
          sx = srcWidth - 1 - dx;
          sy = srcHeight - 1 - dy;
        case 270:
          sx = srcWidth - 1 - dy;
          sy = dx;
        default:
          sx = dx;
          sy = dy;
      }
      final index = sy * plane.bytesPerRow + sx * pixelStride + channelOffset;
      out[y * outWidth + x] = index < bytes.length ? bytes[index] : 0;
    }
  }
  return _GrayFrame(outWidth, outHeight, out);
}

_GrayFrame _grayFrameFromImage(img.Image image) {
  final small = image.width > _idAnalysisWidth
      ? img.copyResize(
          image,
          width: _idAnalysisWidth,
          interpolation: img.Interpolation.nearest,
        )
      : image;
  final out = Uint8List(small.width * small.height);
  var i = 0;
  for (final pixel in small) {
    out[i++] = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
        .round()
        .clamp(0, 255);
  }
  return _GrayFrame(small.width, small.height, out);
}

enum _IdFrameIssue { noCard, tooDark, tooBright, glare, blurry, moving, none }

extension on _IdFrameIssue {
  String get hint {
    switch (this) {
      case _IdFrameIssue.noCard:
        return 'Ilagay ang buong ID sa loob ng frame';
      case _IdFrameIssue.tooDark:
        return 'Masyadong madilim. Lumipat sa maliwanag na lugar.';
      case _IdFrameIssue.tooBright:
        return 'Masyadong maliwanag. Iwasan ang direktang ilaw.';
      case _IdFrameIssue.glare:
        return 'May silaw sa ID. Ikiling nang kaunti ang ID.';
      case _IdFrameIssue.blurry:
        return 'Malabo. Ilapit nang kaunti at hawakan nang steady.';
      case _IdFrameIssue.moving:
        return 'Huwag gumalaw...';
      case _IdFrameIssue.none:
        return 'Hawakan lang, kinukuha na...';
    }
  }
}

class _IdFrameAnalyzer {
  List<double>? _previousBlocks;

  void reset() => _previousBlocks = null;

  _IdFrameIssue analyze(_GrayFrame frame) {
    final guide = _idGuideRect(frame.width.toDouble(), frame.height.toDouble());
    final left = guide.left.round();
    final top = guide.top.round();
    final right = guide.right.round();
    final bottom = guide.bottom.round();
    final insetX = (guide.width * 0.1).round();
    final insetY = (guide.height * 0.1).round();
    final x0 = left + insetX;
    final x1 = right - insetX;
    final y0 = top + insetY;
    final y1 = bottom - insetY;

    var sum = 0;
    var glare = 0;
    var count = 0;
    var lapSum = 0.0;
    var lapSquares = 0.0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final value = frame.at(x, y);
        sum += value;
        if (value >= 248) glare++;
        count++;
        final laplacian =
            4 * value -
            frame.at(x - 1, y) -
            frame.at(x + 1, y) -
            frame.at(x, y - 1) -
            frame.at(x, y + 1);
        lapSum += laplacian;
        lapSquares += laplacian * laplacian;
      }
    }
    if (count == 0) return _IdFrameIssue.noCard;
    final brightness = sum / count;
    final lapMean = lapSum / count;
    final sharpness = lapSquares / count - lapMean * lapMean;

    final motion = _motionScore(frame, x0, y0, x1, y1);

    if (brightness < _idMinBrightness) return _IdFrameIssue.tooDark;

    final band = math.max(3, (guide.height * 0.12).round());
    var sides = 0;
    if (_hasEdge(frame, true, top, left, right, band)) sides++;
    if (_hasEdge(frame, true, bottom, left, right, band)) sides++;
    if (_hasEdge(frame, false, left, top, bottom, band)) sides++;
    if (_hasEdge(frame, false, right, top, bottom, band)) sides++;
    if (sides < 3) return _IdFrameIssue.noCard;

    if (brightness > _idMaxBrightness) return _IdFrameIssue.tooBright;
    if (glare / count > _idMaxGlareFraction) return _IdFrameIssue.glare;
    if (sharpness < _idMinSharpness) return _IdFrameIssue.blurry;
    if (motion > _idMaxMotion) return _IdFrameIssue.moving;
    return _IdFrameIssue.none;
  }

  /// Mean absolute change of 8x8 block averages since the previous frame.
  double _motionScore(_GrayFrame frame, int x0, int y0, int x1, int y1) {
    const block = 8;
    final blocks = <double>[];
    for (var by = y0; by + block <= y1; by += block) {
      for (var bx = x0; bx + block <= x1; bx += block) {
        var total = 0;
        for (var y = by; y < by + block; y++) {
          for (var x = bx; x < bx + block; x++) {
            total += frame.at(x, y);
          }
        }
        blocks.add(total / (block * block));
      }
    }
    final previous = _previousBlocks;
    _previousBlocks = blocks;
    if (previous == null || previous.length != blocks.length) {
      return double.infinity;
    }
    var diff = 0.0;
    for (var i = 0; i < blocks.length; i++) {
      diff += (blocks[i] - previous[i]).abs();
    }
    return blocks.isEmpty ? 0 : diff / blocks.length;
  }

  /// Looks for one continuous card edge near a guide side. For every column
  /// (or row) along the side, the strongest gradient inside [band] is found;
  /// the edge counts when most positions have one and they line up smoothly.
  bool _hasEdge(
    _GrayFrame frame,
    bool horizontal,
    int line,
    int start,
    int end,
    int band,
  ) {
    final acrossLimit = horizontal ? frame.height : frame.width;
    final spanStart = start + ((end - start) * 0.15).round();
    final spanEnd = end - ((end - start) * 0.15).round();
    final from = math.max(1, line - band);
    final to = math.min(acrossLimit - 2, line + band);
    if (to <= from || spanEnd <= spanStart) return false;

    int pixel(int along, int across) =>
        horizontal ? frame.at(along, across) : frame.at(across, along);

    var hits = 0;
    var smoothPairs = 0;
    var pairs = 0;
    int? previousRow;
    for (var along = spanStart; along < spanEnd; along++) {
      var bestGradient = 0;
      var bestRow = from;
      for (var across = from; across <= to; across++) {
        final gradient = (pixel(along, across + 1) - pixel(along, across - 1))
            .abs();
        if (gradient > bestGradient) {
          bestGradient = gradient;
          bestRow = across;
        }
      }
      if (bestGradient >= _idEdgeGradientThreshold) {
        hits++;
        if (previousRow != null) {
          pairs++;
          if ((bestRow - previousRow).abs() <= 2) smoothPairs++;
        }
        previousRow = bestRow;
      } else {
        previousRow = null;
      }
    }
    final coverage = hits / (spanEnd - spanStart);
    final smoothness = pairs == 0 ? 0 : smoothPairs / pairs;
    return coverage >= _idMinEdgeCoverage && smoothness >= _idMinEdgeSmoothness;
  }
}

/// Crops a captured photo to the guide area. [input] is the encoded photo
/// and the aspect ratio of the preview the user aligned the ID against.
/// Runs in a background isolate on mobile via [compute].
Uint8List _cropIdPhoto((Uint8List, double) input) {
  final (bytes, previewAspect) = input;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  var photo = img.bakeOrientation(decoded);
  if ((photo.width > photo.height) != (previewAspect > 1)) {
    photo = img.copyRotate(photo, angle: 90);
  }
  // The preview shows a centered crop of the photo with previewAspect.
  var visibleWidth = photo.width.toDouble();
  var visibleHeight = photo.height.toDouble();
  if (visibleWidth / visibleHeight > previewAspect) {
    visibleWidth = visibleHeight * previewAspect;
  } else {
    visibleHeight = visibleWidth / previewAspect;
  }
  final offsetX = (photo.width - visibleWidth) / 2;
  final offsetY = (photo.height - visibleHeight) / 2;
  final guide = _idGuideRect(
    visibleWidth,
    visibleHeight,
  ).inflate(visibleWidth * 0.03).shift(Offset(offsetX, offsetY));
  final left = guide.left.clamp(0, photo.width - 1).round();
  final top = guide.top.clamp(0, photo.height - 1).round();
  final right = guide.right.clamp(left + 1, photo.width).round();
  final bottom = guide.bottom.clamp(top + 1, photo.height).round();
  final cropped = img.copyCrop(
    photo,
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
  );
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
}

/// Opens the auto-scanner (gallery on desktop) and returns the ID photo
/// compressed to fit a Firestore document, or an error message to show.
/// Both fields are null when the citizen cancels.
Future<({Uint8List? bytes, String? error})> scanGovernmentIdPhoto(
  BuildContext context,
  String idType,
) async {
  final hasLiveScanner =
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  final capture = hasLiveScanner
      ? await showDialog<XFile>(
          context: context,
          barrierDismissible: false,
          builder: (_) => IdAutoScannerDialog(idType: idType),
        )
      : await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1800,
        );
  if (capture == null) return (bytes: null, error: null);
  final decoded = img.decodeImage(await capture.readAsBytes());
  if (decoded == null) {
    return (bytes: null, error: 'Hindi mabasa ang scan. Ulitin.');
  }
  final resized = decoded.width > 1400
      ? img.copyResize(decoded, width: 1400)
      : decoded;
  final bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 55));
  if (bytes.length > 450 * 1024) {
    return (bytes: null, error: 'ID image must be under 450 KB.');
  }
  return (bytes: bytes, error: null);
}

/// Runs the advisory Gemini review and returns the `governmentIdAiReview`
/// value to store. Failures resolve to a manual-review marker, because an
/// Admin reviews every ID anyway.
Future<Map<String, dynamic>> reviewGovernmentIdForProfile({
  required String idType,
  required Uint8List imageBytes,
  required String citizenName,
}) async {
  try {
    final ai = await reviewCitizenIdWithGemini(
      idType: idType,
      imageBytes: imageBytes,
      citizenName: citizenName,
    );
    final confidence = (ai['confidence'] as num?)?.toDouble() ?? 0;
    return {
      'status': 'completed',
      'documentType': '${ai['documentType'] ?? 'unclear'}',
      'readable': ai['readable'] == true,
      'appearsGovernmentIssued': ai['appearsGovernmentIssued'] == true,
      'confidence': confidence.clamp(0, 1),
      'concerns': (ai['concerns'] is List)
          ? (ai['concerns'] as List).take(8).map((item) => '$item').toList()
          : <String>[],
      'recommendation': '${ai['recommendation'] ?? 'manual_review'}',
      'model': idReviewModel,
      'reviewedAt': FieldValue.serverTimestamp(),
    };
  } catch (_) {
    return {
      'status': 'error',
      'recommendation': 'manual_review',
      'reviewedAt': FieldValue.serverTimestamp(),
    };
  }
}

enum _IdScanPhase { starting, scanning, capturing, verifying, success, expired }

class IdAutoScannerDialog extends StatefulWidget {
  const IdAutoScannerDialog({super.key, required this.idType});

  final String idType;

  @override
  State<IdAutoScannerDialog> createState() => _IdAutoScannerDialogState();
}

class _IdAutoScannerDialogState extends State<IdAutoScannerDialog>
    with SingleTickerProviderStateMixin {
  final _analyzer = _IdFrameAnalyzer();
  late final AnimationController _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  CameraController? _controller;
  _IdScanPhase _phase = _IdScanPhase.starting;
  _IdFrameIssue _issue = _IdFrameIssue.noCard;
  String? _error;
  String? _rejection;
  Uint8List? _capturedBytes;
  int _stableFrames = 0;
  int _rejections = 0;
  bool _analyzing = false;
  bool _webLoopRunning = false;
  bool _showFallback = false;
  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _fallbackTimer;
  Timer? _expiryTimer;
  int _secondsLeft = _idScanTimeoutSeconds;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _expiryTimer?.cancel();
    _scanLine.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera found');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        kIsWeb ? ResolutionPreset.high : ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: kIsWeb ? null : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _secondsLeft = _idScanTimeoutSeconds;
      });
      _fallbackTimer?.cancel();
      _fallbackTimer = Timer(_idFallbackDelay, () {
        if (mounted) setState(() => _showFallback = true);
      });
      _expiryTimer?.cancel();
      _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        // The countdown pauses while a capture is being checked by the AI.
        if (!mounted || _phase != _IdScanPhase.scanning) return;
        if (_secondsLeft <= 1) {
          _expire();
        } else {
          setState(() => _secondsLeft--);
        }
      });
      await _resumeScanning();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Hindi ma-access ang camera.');
      }
    }
  }

  /// Ends the scan session and releases the camera.
  Future<void> _expire() async {
    _expiryTimer?.cancel();
    _fallbackTimer?.cancel();
    final controller = _controller;
    setState(() {
      _phase = _IdScanPhase.expired;
      _controller = null;
      _secondsLeft = 0;
    });
    if (controller != null) {
      if (!kIsWeb && controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
  }

  void _restartScan() {
    setState(() {
      _phase = _IdScanPhase.starting;
      _rejection = null;
      _rejections = 0;
      _showFallback = false;
      _issue = _IdFrameIssue.noCard;
    });
    _startCamera();
  }

  Future<void> _resumeScanning() async {
    final controller = _controller;
    if (!mounted || controller == null) return;
    _analyzer.reset();
    setState(() {
      _phase = _IdScanPhase.scanning;
      _stableFrames = 0;
      _capturedBytes = null;
    });
    if (kIsWeb) {
      unawaited(_runWebLoop());
    } else if (!controller.value.isStreamingImages) {
      await controller.startImageStream(_onCameraImage);
    }
  }

  int _streamRotation(CameraController controller) {
    final sensor = controller.description.sensorOrientation;
    final device = switch (controller.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    return controller.description.lensDirection == CameraLensDirection.front
        ? (sensor + device) % 360
        : (sensor - device + 360) % 360;
  }

  void _onCameraImage(CameraImage image) {
    final controller = _controller;
    if (controller == null || _phase != _IdScanPhase.scanning || _analyzing) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastAnalysis) < _idAnalysisInterval) return;
    _lastAnalysis = now;
    _analyzing = true;
    try {
      final rotation = _streamRotation(controller);
      final frame = _grayFrameFromCameraImage(image, rotation);
      _handleFrame(frame, null);
    } finally {
      _analyzing = false;
    }
  }

  /// Web has no image stream. Small frames are read from the <video> element
  /// instead; takePicture (a full-resolution JPEG round trip) is only the
  /// fallback when the video element cannot be read.
  Future<void> _runWebLoop() async {
    if (_webLoopRunning) return;
    _webLoopRunning = true;
    try {
      while (mounted && _phase == _IdScanPhase.scanning) {
        final controller = _controller;
        if (controller == null) break;
        try {
          final live = grabVideoGrayFrame(_idAnalysisWidth);
          if (live != null) {
            final (width, height, pixels) = live;
            _handleFrame(_GrayFrame(width, height, pixels), null);
          } else {
            final shot = await controller.takePicture();
            final bytes = await shot.readAsBytes();
            final decoded = img.decodeImage(bytes);
            if (decoded != null && mounted && _phase == _IdScanPhase.scanning) {
              _handleFrame(_grayFrameFromImage(decoded), bytes);
            }
          }
        } catch (_) {
          // A dropped frame is harmless; try the next one.
        }
        await Future<void>.delayed(_idAnalysisInterval);
      }
    } finally {
      _webLoopRunning = false;
    }
  }

  void _handleFrame(_GrayFrame frame, Uint8List? webShot) {
    final issue = _analyzer.analyze(frame);
    _stableFrames = issue == _IdFrameIssue.none ? _stableFrames + 1 : 0;
    if (!mounted) return;
    setState(() {
      _issue = issue;
      if (issue != _IdFrameIssue.noCard) _rejection = null;
    });
    if (_stableFrames >= _idStableFramesRequired) {
      _capture(webShot: webShot, webAspect: frame.aspectRatio);
    }
  }

  Future<void> _capture({Uint8List? webShot, double? webAspect}) async {
    final controller = _controller;
    if (controller == null || _phase != _IdScanPhase.scanning) return;
    setState(() => _phase = _IdScanPhase.capturing);
    try {
      Uint8List raw;
      double previewAspect;
      if (kIsWeb) {
        raw = webShot ?? await (await controller.takePicture()).readAsBytes();
        previewAspect = webAspect!;
      } else {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
        final shot = await controller.takePicture();
        raw = await shot.readAsBytes();
        final rotation = _streamRotation(controller);
        final aspect = controller.value.aspectRatio;
        previewAspect = rotation == 90 || rotation == 270 ? 1 / aspect : aspect;
      }
      final cropped = await compute(_cropIdPhoto, (raw, previewAspect));
      if (!mounted) return;
      setState(() {
        _phase = _IdScanPhase.verifying;
        _capturedBytes = cropped;
      });

      final rejection = await _aiPrecheck(cropped);
      if (!mounted) return;
      if (rejection != null) {
        setState(() {
          _rejection = rejection;
          _rejections++;
          if (_rejections >= 2) _showFallback = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        await _resumeScanning();
        return;
      }

      setState(() => _phase = _IdScanPhase.success);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.pop(
        context,
        XFile.fromData(
          cropped,
          name: 'government_id_scan.jpg',
          mimeType: 'image/jpeg',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _rejection = 'Hindi nakuha ang larawan. Subukan ulit.');
      await _resumeScanning();
    }
  }

  /// Returns a user-facing reason when the AI flags the capture, or null when
  /// it can be accepted. If the AI is unreachable the capture is accepted,
  /// because every ID is still reviewed manually by an admin.
  Future<String?> _aiPrecheck(Uint8List bytes) async {
    try {
      final result = await precheckIdCaptureWithGemini(
        idType: widget.idType,
        imageBytes: bytes,
      ).timeout(const Duration(seconds: 15));
      if (result['isGovernmentId'] == false) {
        return 'Hindi ito mukhang valid government ID.';
      }
      if (result['readable'] == false) {
        return 'Hindi mabasa ang ID. Subukan ulit sa mas maliwanag na lugar.';
      }
      if (result['matchesExpectedType'] == false) {
        return 'Hindi tugma sa napiling ID type (${widget.idType}).';
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickFromGallery() async {
    final navigator = Navigator.of(context);
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (mounted && image != null) navigator.pop(image);
  }

  Color get _guideColor {
    switch (_phase) {
      case _IdScanPhase.capturing:
      case _IdScanPhase.verifying:
      case _IdScanPhase.success:
        return Colors.greenAccent;
      case _IdScanPhase.expired:
        return Colors.white;
      case _IdScanPhase.starting:
      case _IdScanPhase.scanning:
        if (_issue == _IdFrameIssue.none) return Colors.greenAccent;
        if (_issue == _IdFrameIssue.noCard) return Colors.white;
        return Colors.amberAccent;
    }
  }

  String get _statusText {
    switch (_phase) {
      case _IdScanPhase.starting:
        return 'Binubuksan ang camera...';
      case _IdScanPhase.scanning:
        return _rejection ?? _issue.hint;
      case _IdScanPhase.capturing:
        return 'Kinukuha ang ID...';
      case _IdScanPhase.verifying:
        return 'Sinusuri ng AI ang ID...';
      case _IdScanPhase.success:
        return 'Na-scan na ang ID!';
      case _IdScanPhase.expired:
        return 'Nag-expire ang scan.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Scan government ID'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _phase == _IdScanPhase.expired
            ? _buildExpired()
            : _error != null
            ? _buildError()
            : controller == null || !controller.value.isInitialized
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: CameraPreview(
                      controller,
                      child: CustomPaint(
                        painter: _IdGuidePainter(
                          color: _guideColor,
                          scan: _scanLine,
                          showScanLine: _phase == _IdScanPhase.scanning,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    top: 16,
                    child: Text(
                      'Ilagay ang harap ng iyong ${widget.idType} sa loob ng '
                      'frame. Kusa itong makukuhanan.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  if (_phase == _IdScanPhase.scanning)
                    Positioned(right: 16, top: 56, child: _buildCountdown()),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 28,
                    child: _buildStatusPanel(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusPanel() {
    final captured = _capturedBytes;
    final isWorking =
        _phase == _IdScanPhase.capturing || _phase == _IdScanPhase.verifying;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (captured != null && _phase != _IdScanPhase.scanning) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(captured, height: 90, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _guideColor.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWorking)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.greenAccent,
                  ),
                )
              else
                Icon(
                  _phase == _IdScanPhase.success
                      ? Icons.check_circle_rounded
                      : _rejection != null
                      ? Icons.error_outline_rounded
                      : Icons.badge_outlined,
                  color: _rejection != null && _phase == _IdScanPhase.scanning
                      ? Colors.redAccent
                      : _guideColor,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showFallback && _phase == _IdScanPhase.scanning) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.upload_file_rounded, color: Colors.white70),
            label: const Text(
              'Hirap ma-scan? Pumili na lang ng larawan',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCountdown() {
    final urgent = _secondsLeft <= 10;
    final color = urgent ? Colors.redAccent : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: urgent ? Colors.redAccent : Colors.white38),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '${_secondsLeft}s',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.timer_off_outlined,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Nag-expire ang scan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Walang na-scan na ID sa loob ng $_idScanTimeoutSeconds '
              'segundo, kaya pinatay muna ang camera.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _restartScan,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('SCAN ULIT'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(
                Icons.upload_file_rounded,
                color: Colors.white70,
              ),
              label: const Text(
                'PUMILI NG LARAWAN',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('PUMILI NG LARAWAN'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() => _error = null);
                _startCamera();
              },
              child: const Text('SUBUKAN ULIT'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdGuidePainter extends CustomPainter {
  _IdGuidePainter({
    required this.color,
    required this.scan,
    required this.showScanLine,
  }) : super(repaint: scan);

  final Color color;
  final Animation<double> scan;
  final bool showScanLine;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = _idGuideRect(size.width, size.height);
    final frame = RRect.fromRectAndRadius(guide, const Radius.circular(14));

    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(frame),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: 0.5),
    );

    final corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;
    final length = guide.shortestSide * 0.2;
    for (final (point, dx, dy) in [
      (guide.topLeft, 1.0, 1.0),
      (guide.topRight, -1.0, 1.0),
      (guide.bottomLeft, 1.0, -1.0),
      (guide.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(point.dx, point.dy + dy * length)
          ..lineTo(point.dx, point.dy)
          ..lineTo(point.dx + dx * length, point.dy),
        corner,
      );
    }

    if (showScanLine) {
      final y = guide.top + guide.height * scan.value;
      canvas.drawLine(
        Offset(guide.left + 12, y),
        Offset(guide.right - 12, y),
        Paint()
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(_IdGuidePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.showScanLine != showScanLine;
}
