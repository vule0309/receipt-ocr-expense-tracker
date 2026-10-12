import 'package:flutter/material.dart';

class FramingCropOverlay extends StatelessWidget {
  final Rect? scanRect;

  const FramingCropOverlay({
    super.key,
    this.scanRect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // Framing rectangle: 80% width, aspect ratio approx 1:1.6 (standard tall receipt)
        final frameWidth = width * 0.82;
        final frameHeight = height * 0.65;
        final left = (width - frameWidth) / 2;
        final top = (height - frameHeight) / 2.3;

        final targetRect = scanRect ?? Rect.fromLTWH(left, top, frameWidth, frameHeight);

        return Stack(
          children: [
            CustomPaint(
              size: Size(width, height),
              painter: _FramingPainter(frameRect: targetRect),
            ),
            Positioned(
              top: targetRect.bottom + 16,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Align receipt edges inside the frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FramingPainter extends CustomPainter {
  final Rect frameRect;

  _FramingPainter({required this.frameRect});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark background with transparent hole for receipt
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(bgPath, bgPaint);

    // 2. Framing border
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(16)),
      borderPaint,
    );

    // 3. Highlighted Corner Brackets (Doc Scanner style)
    final cornerPaint = Paint()
      ..color = const Color(0xFF6366F1) // vibrant primary accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;
    const cornerRadius = 16.0;

    // Top-Left
    final tlPath = Path()
      ..moveTo(frameRect.left, frameRect.top + cornerLength)
      ..lineTo(frameRect.left, frameRect.top + cornerRadius)
      ..arcToPoint(
        Offset(frameRect.left + cornerRadius, frameRect.top),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(frameRect.left + cornerLength, frameRect.top);
    canvas.drawPath(tlPath, cornerPaint);

    // Top-Right
    final trPath = Path()
      ..moveTo(frameRect.right - cornerLength, frameRect.top)
      ..lineTo(frameRect.right - cornerRadius, frameRect.top)
      ..arcToPoint(
        Offset(frameRect.right, frameRect.top + cornerRadius),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(frameRect.right, frameRect.top + cornerLength);
    canvas.drawPath(trPath, cornerPaint);

    // Bottom-Left
    final blPath = Path()
      ..moveTo(frameRect.left, frameRect.bottom - cornerLength)
      ..lineTo(frameRect.left, frameRect.bottom - cornerRadius)
      ..arcToPoint(
        Offset(frameRect.left + cornerRadius, frameRect.bottom),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(frameRect.left + cornerLength, frameRect.bottom);
    canvas.drawPath(blPath, cornerPaint);

    // Bottom-Right
    final brPath = Path()
      ..moveTo(frameRect.right - cornerLength, frameRect.bottom)
      ..lineTo(frameRect.right - cornerRadius, frameRect.bottom)
      ..arcToPoint(
        Offset(frameRect.right, frameRect.bottom - cornerRadius),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(frameRect.right, frameRect.bottom - cornerLength);
    canvas.drawPath(brPath, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _FramingPainter oldDelegate) {
    return oldDelegate.frameRect != frameRect;
  }
}
