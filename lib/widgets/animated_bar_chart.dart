import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/currency_formatter.dart';

class AnimatedBarChart extends StatefulWidget {
  final Map<int, double> weeklyData; // 1 (Mon) to 7 (Sun)
  final Duration animationDuration;

  const AnimatedBarChart({
    super.key,
    required this.weeklyData,
    this.animationDuration = const Duration(milliseconds: 1000),
  });

  @override
  State<AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<AnimatedBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _selectedDayIndex; // 1 to 7

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weeklyData != widget.weeklyData) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(Offset localPosition, Size size) {
    const leftPadding = 45.0;
    const rightPadding = 16.0;

    final chartWidth = size.width - leftPadding - rightPadding;

    if (localPosition.dx < leftPadding || localPosition.dx > size.width - rightPadding) {
      setState(() => _selectedDayIndex = null);
      return;
    }

    final slotWidth = chartWidth / 7;
    final tappedSlot = ((localPosition.dx - leftPadding) / slotWidth).floor();
    final dayIndex = tappedSlot + 1; // 1 to 7

    if (dayIndex >= 1 && dayIndex <= 7) {
      setState(() {
        if (_selectedDayIndex == dayIndex) {
          _selectedDayIndex = null;
        } else {
          _selectedDayIndex = dayIndex;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTapUp: (details) => _handleTap(details.localPosition, const Size(double.infinity, 220)),
          child: SizedBox(
            height: 220,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 220),
                  painter: _BarChartPainter(
                    weeklyData: widget.weeklyData,
                    progress: _animation.value,
                    selectedDayIndex: _selectedDayIndex,
                    primaryColor: Theme.of(context).primaryColor,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final Map<int, double> weeklyData;
  final double progress;
  final int? selectedDayIndex;
  final Color primaryColor;

  static const List<String> _dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  _BarChartPainter({
    required this.weeklyData,
    required this.progress,
    this.selectedDayIndex,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 48.0;
    const rightPadding = 16.0;
    const bottomPadding = 28.0;
    const topPadding = 28.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    // 1. Calculate max value and average
    double maxVal = 0.0;
    double sumVal = 0.0;
    for (int day = 1; day <= 7; day++) {
      final val = weeklyData[day] ?? 0.0;
      if (val > maxVal) maxVal = val;
      sumVal += val;
    }
    final avgVal = sumVal / 7;

    // If max is 0, give default ceiling so grid paints nicely
    if (maxVal <= 0) maxVal = 100000;
    // Round max value up to a nice number
    final maxCeiling = _niceCeiling(maxVal);

    // 2. Draw Horizontal Gridlines & Y-Axis Labels
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = topPadding + (chartHeight / gridLines) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      final labelVal = maxCeiling * (1 - i / gridLines);
      _drawText(
        canvas: canvas,
        text: CurrencyFormatter.formatCompact(labelVal),
        position: Offset(leftPadding - 8, y),
        alignment: Alignment.centerRight,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    // 3. Draw Average Guideline (dashed line)
    if (avgVal > 0) {
      final avgY = topPadding + chartHeight * (1 - (avgVal / maxCeiling).clamp(0.0, 1.0));
      final avgPaint = Paint()
        ..color = Colors.amber.shade700
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      _drawDashedLine(
        canvas: canvas,
        start: Offset(leftPadding, avgY),
        end: Offset(size.width - rightPadding, avgY),
        paint: avgPaint,
      );

      _drawText(
        canvas: canvas,
        text: 'Avg',
        position: Offset(size.width - rightPadding - 2, avgY - 10),
        alignment: Alignment.bottomRight,
        style: TextStyle(
          color: Colors.amber.shade800,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // 4. Draw Bars & X-Axis Labels
    final slotWidth = chartWidth / 7;
    final barWidth = math.min(slotWidth * 0.55, 26.0);

    for (int day = 1; day <= 7; day++) {
      final val = weeklyData[day] ?? 0.0;
      final isSelected = selectedDayIndex == day;

      final slotCenter = leftPadding + (day - 0.5) * slotWidth;
      final targetBarHeight = (val / maxCeiling).clamp(0.0, 1.0) * chartHeight;
      final currentBarHeight = targetBarHeight * progress;

      final barLeft = slotCenter - (barWidth / 2);
      final barTop = topPadding + chartHeight - currentBarHeight;
      final barBottom = topPadding + chartHeight;

      // Draw Bar
      final rect = Rect.fromLTRB(barLeft, barTop, barLeft + barWidth, barBottom);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      final barGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isSelected
            ? [const Color(0xFFFF6B6B), const Color(0xFFEE5253)]
            : [
                primaryColor.withOpacity(0.9),
                primaryColor.withOpacity(0.65),
              ],
      );

      final barPaint = Paint()
        ..shader = barGradient.createShader(rect);

      // If bar height > 0, draw rounded bar
      if (currentBarHeight > 0) {
        // Shadow for selected bar
        if (isSelected) {
          canvas.drawRRect(
            rrect.inflate(2),
            Paint()
              ..color = const Color(0xFFFF6B6B).withOpacity(0.3)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
        canvas.drawRRect(rrect, barPaint);
      } else {
        // Subtle base dot for 0 value days
        canvas.drawCircle(
          Offset(slotCenter, barBottom - 2),
          2,
          Paint()..color = Colors.grey.shade300,
        );
      }

      // Draw X-Axis Day Label
      _drawText(
        canvas: canvas,
        text: _dayLabels[day - 1],
        position: Offset(slotCenter, barBottom + 8),
        alignment: Alignment.topCenter,
        style: TextStyle(
          color: isSelected ? primaryColor : Colors.grey.shade600,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
      );

      // 5. Draw Interactive Canvas Tooltip if selected
      if (isSelected && progress > 0.5) {
        _drawTooltip(
          canvas: canvas,
          center: Offset(slotCenter, barTop),
          text: CurrencyFormatter.formatVND(val),
          dayName: _dayLabels[day - 1],
        );
      }
    }
  }

  void _drawTooltip({
    required Canvas canvas,
    required Offset center,
    required String text,
    required String dayName,
  }) {
    const tooltipWidth = 84.0;
    const tooltipHeight = 26.0;
    final tooltipRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 20),
      width: tooltipWidth,
      height: tooltipHeight,
    );

    // Background bubble
    final bgPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(tooltipRect, const Radius.circular(6));
    canvas.drawRRect(rrect, bgPaint);

    // Arrow pointer pointing down
    final path = Path()
      ..moveTo(center.dx - 4, tooltipRect.bottom)
      ..lineTo(center.dx + 4, tooltipRect.bottom)
      ..lineTo(center.dx, tooltipRect.bottom + 4)
      ..close();
    canvas.drawPath(path, bgPaint);

    // Tooltip text
    _drawText(
      canvas: canvas,
      text: text,
      position: tooltipRect.center,
      alignment: Alignment.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  void _drawDashedLine({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required Paint paint,
  }) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double currentX = start.dx;
    while (currentX < end.dx) {
      canvas.drawLine(
        Offset(currentX, start.dy),
        Offset(math.min(currentX + dashWidth, end.dx), start.dy),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  double _niceCeiling(double val) {
    if (val <= 0) return 100000;
    final magnitude = math.pow(10, (math.log(val) / math.ln10).floor()).toDouble();
    final normalized = val / magnitude;
    double nice;
    if (normalized <= 1.0) {
      nice = 1.0;
    } else if (normalized <= 2.0) {
      nice = 2.0;
    } else if (normalized <= 5.0) {
      nice = 5.0;
    } else {
      nice = 10.0;
    }
    return nice * magnitude;
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required Offset position,
    required Alignment alignment,
    required TextStyle style,
  }) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    var dx = position.dx;
    var dy = position.dy;

    if (alignment == Alignment.center) {
      dx -= textPainter.width / 2;
      dy -= textPainter.height / 2;
    } else if (alignment == Alignment.centerRight) {
      dx -= textPainter.width;
      dy -= textPainter.height / 2;
    } else if (alignment == Alignment.topCenter) {
      dx -= textPainter.width / 2;
    } else if (alignment == Alignment.bottomRight) {
      dx -= textPainter.width;
      dy -= textPainter.height;
    }

    textPainter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedDayIndex != selectedDayIndex ||
        oldDelegate.weeklyData != weeklyData;
  }
}

