import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, WriteBuffer;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';
import '../../routes.dart';

enum LivenessStep {
  lookStraight,
  smile,
  turnLeft,
  turnRight,
  blink,
  capturing,
  complete,
}

class LivenessCheckScreen extends StatefulWidget {
  const LivenessCheckScreen({super.key});

  @override
  State<LivenessCheckScreen> createState() => _LivenessCheckScreenState();
}

class _LivenessCheckScreenState extends State<LivenessCheckScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  LivenessStep _currentStep = LivenessStep.lookStraight;
  double _stepProgress = 0.0;
  int _stepHoldCount = 0;
  static const int _requiredHoldFrames = 10; // Hold for ~10 frames to confirm

  XFile? _capturedImage;
  bool _isUploading = false;

  // Thresholds
  static const double _smileThreshold = 0.7;
  static const double _eyeOpenThreshold = 0.3;
  static const double _headTurnThreshold = 25.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _initializeFaceDetector();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (kIsWeb) {
      // Skip camera initialization on web for now
      setState(() {
        _isCameraInitialized = false;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        ToastHelper.showError('No camera available');
        return;
      }

      // Find front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });

        // Start image stream for face detection
        _cameraController!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      ToastHelper.showError('Failed to initialize camera');
    }
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableClassification: true, // For smile and eye detection
      enableTracking: true,
      enableLandmarks: true,
      enableContours: false,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || _currentStep == LivenessStep.complete || _isProcessing) {
      return;
    }

    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        if (mounted) {
          setState(() {
            _stepHoldCount = 0;
          });
        }
        _isDetecting = false;
        return;
      }

      final face = faces.first;
      _processLivenessStep(face);
    } catch (e) {
      debugPrint('Error processing image: $e');
    }

    _isDetecting = false;
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final camera = _cameraController!.description;
      final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);

      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      return InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  void _processLivenessStep(Face face) {
    bool stepPassed = false;

    switch (_currentStep) {
      case LivenessStep.lookStraight:
        // Check if face is looking relatively straight
        final headY = face.headEulerAngleY ?? 0;
        final headZ = face.headEulerAngleZ ?? 0;
        if (headY.abs() < 15 && headZ.abs() < 15) {
          stepPassed = true;
        }
        break;

      case LivenessStep.smile:
        final smileProb = face.smilingProbability ?? 0;
        if (smileProb > _smileThreshold) {
          stepPassed = true;
        }
        break;

      case LivenessStep.turnLeft:
        final headY = face.headEulerAngleY ?? 0;
        if (headY < -_headTurnThreshold) {
          stepPassed = true;
        }
        break;

      case LivenessStep.turnRight:
        final headY = face.headEulerAngleY ?? 0;
        if (headY > _headTurnThreshold) {
          stepPassed = true;
        }
        break;

      case LivenessStep.blink:
        final leftEye = face.leftEyeOpenProbability ?? 1;
        final rightEye = face.rightEyeOpenProbability ?? 1;
        // Eyes are closed
        if (leftEye < _eyeOpenThreshold && rightEye < _eyeOpenThreshold) {
          stepPassed = true;
        }
        break;

      case LivenessStep.capturing:
      case LivenessStep.complete:
        break;
    }

    if (stepPassed) {
      _stepHoldCount++;
      if (mounted) {
        setState(() {
          _stepProgress = _stepHoldCount / _requiredHoldFrames;
        });
      }

      if (_stepHoldCount >= _requiredHoldFrames) {
        _advanceToNextStep();
      }
    } else {
      if (mounted && _stepHoldCount > 0) {
        setState(() {
          _stepHoldCount = 0;
          _stepProgress = 0;
        });
      }
    }
  }

  void _advanceToNextStep() {
    setState(() {
      _stepHoldCount = 0;
      _stepProgress = 0;

      switch (_currentStep) {
        case LivenessStep.lookStraight:
          _currentStep = LivenessStep.smile;
          break;
        case LivenessStep.smile:
          _currentStep = LivenessStep.turnLeft;
          break;
        case LivenessStep.turnLeft:
          _currentStep = LivenessStep.turnRight;
          break;
        case LivenessStep.turnRight:
          _currentStep = LivenessStep.blink;
          break;
        case LivenessStep.blink:
          _currentStep = LivenessStep.capturing;
          _capturePhoto();
          break;
        case LivenessStep.capturing:
        case LivenessStep.complete:
          break;
      }
    });
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Stop image stream before capturing
      await _cameraController!.stopImageStream();
      
      // Small delay to ensure stream is stopped
      await Future.delayed(const Duration(milliseconds: 200));

      final image = await _cameraController!.takePicture();

      setState(() {
        _capturedImage = image;
        _currentStep = LivenessStep.complete;
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      setState(() {
        _isProcessing = false;
      });
      ToastHelper.showError('Failed to capture photo');
    }
  }

  Future<void> _uploadPhotoAndProceed() async {
    if (_capturedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Read the image bytes
      final bytes = await _capturedImage!.readAsBytes();
      
      // Upload profile photo
      final result = await authService.updateProfilePhoto(bytes, _capturedImage!.name);

      if (!mounted) return;

      if (result['success'] == true) {
        ToastHelper.showSuccess('Photo uploaded successfully!');
        
        // Navigate to PIN setup
        Navigator.pushReplacementNamed(context, AppRoutes.pinSetup);
      } else {
        ToastHelper.showError(result['message'] ?? 'Failed to upload photo');
        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      if (mounted) {
        ToastHelper.showError('Failed to upload photo');
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _skipLivenessCheck() {
    Navigator.pushReplacementNamed(context, AppRoutes.pinSetup);
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case LivenessStep.lookStraight:
        return 'Look Straight';
      case LivenessStep.smile:
        return 'Smile';
      case LivenessStep.turnLeft:
        return 'Turn Left';
      case LivenessStep.turnRight:
        return 'Turn Right';
      case LivenessStep.blink:
        return 'Blink Your Eyes';
      case LivenessStep.capturing:
        return 'Capturing...';
      case LivenessStep.complete:
        return 'Verification Complete!';
    }
  }

  String _getStepDescription() {
    switch (_currentStep) {
      case LivenessStep.lookStraight:
        return 'Position your face in the circle and look straight at the camera';
      case LivenessStep.smile:
        return 'Give us a big smile!';
      case LivenessStep.turnLeft:
        return 'Slowly turn your head to the left';
      case LivenessStep.turnRight:
        return 'Slowly turn your head to the right';
      case LivenessStep.blink:
        return 'Blink your eyes naturally';
      case LivenessStep.capturing:
        return 'Hold still while we capture your photo...';
      case LivenessStep.complete:
        return 'Your identity has been verified successfully!';
    }
  }

  IconData _getStepIcon() {
    switch (_currentStep) {
      case LivenessStep.lookStraight:
        return Icons.face;
      case LivenessStep.smile:
        return Icons.sentiment_very_satisfied;
      case LivenessStep.turnLeft:
        return Icons.arrow_back;
      case LivenessStep.turnRight:
        return Icons.arrow_forward;
      case LivenessStep.blink:
        return Icons.visibility_off;
      case LivenessStep.capturing:
        return Icons.camera_alt;
      case LivenessStep.complete:
        return Icons.check_circle;
    }
  }

  int _getCurrentStepIndex() {
    switch (_currentStep) {
      case LivenessStep.lookStraight:
        return 0;
      case LivenessStep.smile:
        return 1;
      case LivenessStep.turnLeft:
        return 2;
      case LivenessStep.turnRight:
        return 3;
      case LivenessStep.blink:
        return 4;
      case LivenessStep.capturing:
      case LivenessStep.complete:
        return 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle web platform
    if (kIsWeb) {
      return _buildWebFallback();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Camera Preview
            Expanded(
              child: _buildCameraSection(),
            ),

            // Instructions & Actions
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWebFallback() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 64,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Liveness Check',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Liveness check is not available on web browsers. Please use the mobile app for identity verification.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _skipLivenessCheck,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue to PIN Setup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Skip Verification?'),
                      content: const Text(
                        'You can complete identity verification later from your profile settings.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _skipLivenessCheck();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Expanded(
                child: Text(
                  'Identity Verification',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          // Progress indicator
          Row(
            children: List.generate(5, (index) {
              final isCompleted = index < _getCurrentStepIndex();
              final isCurrent = index == _getCurrentStepIndex() && _currentStep != LivenessStep.complete;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.primary
                        : isCurrent
                            ? AppColors.primary.withOpacity(0.5)
                            : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    if (_currentStep == LivenessStep.complete && _capturedImage != null) {
      return _buildCapturedPhotoView();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Camera preview with circular clip
            if (_isCameraInitialized && _cameraController != null)
              ClipOval(
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize?.height ?? 1,
                      height: _cameraController!.value.previewSize?.width ?? 1,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            // Circular border with progress
            SizedBox.expand(
              child: CustomPaint(
                painter: CircleProgressPainter(
                  progress: _stepProgress,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  progressColor: AppColors.primary,
                ),
              ),
            ),

            // Step icon overlay
            if (_currentStep == LivenessStep.capturing)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapturedPhotoView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            // Success overlay
            Container(
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green, width: 4),
              ),
            ),
            Positioned(
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _currentStep == LivenessStep.complete
                  ? Colors.green.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStepIcon(),
              size: 32,
              color: _currentStep == LivenessStep.complete
                  ? Colors.green
                  : AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Step title
          Text(
            _getStepTitle(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _currentStep == LivenessStep.complete
                  ? Colors.green
                  : AppColors.textColor,
            ),
          ),
          const SizedBox(height: 8),

          // Step description
          Text(
            _getStepDescription(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Action button (only show when complete)
          if (_currentStep == LivenessStep.complete)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadPhotoAndProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

// Custom painter for circular progress
class CircleProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  CircleProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
