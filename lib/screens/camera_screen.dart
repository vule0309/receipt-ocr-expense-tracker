import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../services/ocr_service.dart';
import '../widgets/framing_crop_overlay.dart';
import 'receipt_review_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  FlashMode _flashMode = FlashMode.off;
  Offset? _focusPoint;
  bool _showFocusIndicator = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(
          _cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (e) {
      debugPrint('Error setting flash mode: $e');
    }
  }

  Future<void> _handleFocusTap(TapUpDetails details) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final offset = details.localPosition;
    setState(() {
      _focusPoint = offset;
      _showFocusIndicator = true;
    });

    try {
      // Normalize to 0.0 - 1.0 range
      final renderBox = context.findRenderObject() as RenderBox;
      final size = renderBox.size;
      final point = Offset(offset.dx / size.width, offset.dy / size.height);

      await _controller!.setFocusPoint(point);
      await _controller!.setExposurePoint(point);
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showFocusIndicator = false);
    });
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final XFile photo = await _controller!.takePicture();
      final file = File(photo.path);

      // Perform crop to framing frame
      final croppedFile = await _cropToFrame(file);
      await _processImageAndNavigate(croppedFile ?? file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture receipt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<File?> _cropToFrame(File original) async {
    try {
      final bytes = await original.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Crop center 82% width, 70% height corresponding to FramingCropOverlay
      final cropWidth = (image.width * 0.82).round();
      final cropHeight = (image.height * 0.70).round();
      final cropX = ((image.width - cropWidth) / 2).round();
      final cropY = ((image.height - cropHeight) / 2.3).round();

      final cropped = img.copyCrop(
        image,
        x: cropX.clamp(0, image.width - 1),
        y: cropY.clamp(0, image.height - 1),
        width: cropWidth.clamp(1, image.width),
        height: cropHeight.clamp(1, image.height),
      );

      final croppedPath = original.path.replaceFirst('.jpg', '_cropped.jpg');
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(img.encodeJpg(cropped));
      return croppedFile;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _isProcessing = true);
      await _processImageAndNavigate(File(picked.path));
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _loadSampleReceipt(String type) {
    String sampleText = '';
    switch (type) {
      case 'winmart':
        sampleText = '''
SIÊU THỊ WINMART
Đ/c: Tầng 1, TTTM Vincom Plaza, Đà Nẵng
ĐT: 0236.3888999
HÓA ĐƠN BÁN HÀNG
Ngày: 12/10/2026 09:45
STT Tên hàng          SL    Thành tiền
01  Sữa tươi Vinamilk  2       72.000
02  Bánh mì sandwich   1       25.000
03  Táo Envy Mỹ 1kg    1      118.000
------------------------------------
Cộng tiền hàng: 215.000
Thuế VAT (8%): 17.200
TỔNG CỘNG: 215.000 VND
Tiền khách đưa: 500.000
Tiền thừa: 285.000
Cảm ơn quý khách!
''';
        break;

      case 'highlands':
        sampleText = '''
HIGHLANDS COFFEE
Chi nhánh Bạch Đằng
HÓA ĐƠN THANH TOÁN
Date: 11/10/2026 15:20
1. Trà sen vàng (L)    1    55.000
2. Freeze Trà Xanh (M) 1    65.000
3. Bánh chuối          1    29.000
----------------------------------
THANH TOÁN: 149.000 đ
Tiền mặt: 200.000
Tiền thối: 51.000
Highlands Coffee xin cảm ơn!
''';
        break;

      case 'fahasa':
        sampleText = '''
NHÀ SÁCH FAHASA
Địa chỉ: Lê Duẩn, Hải Châu, Đà Nẵng
PHIẾU THANH TOÁN
Ngày mua: 10/10/2026 17:30
- Giáo trình Lập trình di động  1  185.000
- Vở kẻ ngang 200 trang        5   75.000
- Bút bi Thiên Long gel        3   30.000
-----------------------------------------
Tổng tiền: 290.000 VND
Thanh toán: 290.000 VND
''';
        break;

      case 'grab':
        sampleText = '''
GRAB VIETNAM
Chuyến xe GrabBike
Ngày: 09/10/2026 18:00
Tài xế: Nguyễn Văn A
Từ: Trường ĐH CNTT & TT Việt - Hàn
Đến: Ký túc xá
Cước phí chuyến đi: 42.000
Phí nền tảng: 3.000
TỔNG CỘNG: 45.000 VND
Phương thức: Ví điện tử
''';
        break;
    }

    final parsed = OcrService.instance.parseRawText(sampleText);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptReviewScreen(
          receiptImage: null,
          parsedReceipt: parsed,
        ),
      ),
    );
  }

  Future<void> _processImageAndNavigate(File imageFile) async {
    try {
      final parsed = await OcrService.instance.recognizeReceipt(imageFile);

      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ReceiptReviewScreen(
            receiptImage: imageFile,
            parsedReceipt: parsed,
          ),
        ),
      );

      if (saved == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Viewfinder or Fallback
          if (_isCameraInitialized && _controller != null)
            GestureDetector(
              onTapUp: _handleFocusTap,
              child: Center(
                child: CameraPreview(_controller!),
              ),
            )
          else
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 72, color: Colors.white54),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera Viewfinder',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'Use gallery image or select a sample receipt below to test offline OCR parsing immediately.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickFromGallery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Pick Image from Gallery'),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Framing Crop Overlay (Rule of thirds / crop brackets)
          const FramingCropOverlay(),

          // 3. Focus Tap Indicator
          if (_showFocusIndicator && _focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 30,
              top: _focusPoint!.dy - 30,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amberAccent, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

          // 4. Top Controls (Close, Flash Toggle, Samples)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // Flash Toggle
                if (_isCameraInitialized)
                  IconButton(
                    icon: Icon(
                      _flashMode == FlashMode.off
                          ? Icons.flash_off_rounded
                          : (_flashMode == FlashMode.auto
                              ? Icons.flash_auto_rounded
                              : (_flashMode == FlashMode.always
                                  ? Icons.flash_on_rounded
                                  : Icons.highlight_rounded)),
                      color: _flashMode == FlashMode.off ? Colors.white70 : Colors.amber,
                    ),
                    onPressed: _toggleFlash,
                    tooltip: 'Toggle Flash (${_flashMode.name})',
                  ),
                // Sample Receipts Menu for Instant Demo
                PopupMenuButton<String>(
                  icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                  tooltip: 'Load Sample Receipts',
                  onSelected: _loadSampleReceipt,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'winmart',
                      child: Text('🛒 WinMart Supermarket (Food)'),
                    ),
                    const PopupMenuItem(
                      value: 'highlands',
                      child: Text('☕ Highlands Coffee (Food)'),
                    ),
                    const PopupMenuItem(
                      value: 'fahasa',
                      child: Text('📚 Fahasa Bookstore (Study)'),
                    ),
                    const PopupMenuItem(
                      value: 'grab',
                      child: Text('🛵 GrabBike Commute (Travel)'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 5. Bottom Controls (Shutter, Gallery Picker)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery Picker
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
                      onPressed: _isProcessing ? null : _pickFromGallery,
                      tooltip: 'Gallery',
                    ),

                    // Shutter Capture Button
                    GestureDetector(
                      onTap: _isProcessing ? null : _captureAndProcess,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: _isProcessing
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Container(
                                  width: 58,
                                  height: 58,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    // Empty spacer for balance
                    const SizedBox(width: 48),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

