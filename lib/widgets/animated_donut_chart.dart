import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../utils/currency_formatter.dart';

class AnimatedDonutChart extends StatefulWidget {
  final Map<ExpenseCategory, double> data;
  final double totalAmount;
  final Duration animationDuration;

  const AnimatedDonutChart({
    super.key,
    required this.data,
    required this.totalAmount,
    this.animationDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<AnimatedDonutChart> createState() => _AnimatedDonutChartState();
}

class _AnimatedDonutChartState extends State<AnimatedDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  ExpenseCategory? _selectedCategory;

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
  void didUpdateWidget(covariant AnimatedDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalAmount != widget.totalAmount ||
        oldWidget.data != widget.data) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final outerRadius = size.width / 2;
    const strokeWidth = 32.0;
    final innerRadius = outerRadius - strokeWidth;

    // Check if tap fell inside the donut ring
    if (distance < innerRadius * 0.7 || distance > outerRadius * 1.2) {
      setState(() {
        _selectedCategory = null;
      });
      return;
    }

    // Calculate angle from -pi to pi, normalize to 0 to 2*pi starting from -pi/2 (top)
    var angle = math.atan2(dy, dx);
    angle += math.pi / 2; // offset so top is 0
    if (angle < 0) {
      angle += 2 * math.pi;
    }

    if (widget.totalAmount <= 0) return;

    double currentAngle = 0;
    ExpenseCategory? hitCategory;

    for (final entry in widget.data.entries) {
      if (entry.value <= 0) continue;
      final sweepAngle = (entry.value / widget.totalAmount) * 2 * math.pi;
      if (angle >= currentAngle && angle <= currentAngle + sweepAngle) {
        hitCategory = entry.key;
        break;
      }
      currentAngle += sweepAngle;
    }

    setState(() {
      if (_selectedCategory == hitCategory) {
        _selectedCategory = null; // deselect if tapped again
      } else {
        _selectedCategory = hitCategory;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalAmount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Donut Chart Canvas
        LayoutBuilder(
          builder: (context, constraints) {
            final chartSize = math.min(constraints.maxWidth * 0.65, 230.0);

            return Center(
              child: GestureDetector(
                onTapUp: (details) => _handleTap(details.localPosition, Size(chartSize, chartSize)),
                child: SizedBox(
                  width: chartSize,
                  height: chartSize,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _DonutChartPainter(
                          data: widget.data,
                          total: total,
                          progress: _animation.value,
                          selectedCategory: _selectedCategory,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedCategory != null
                                      ? _selectedCategory!.displayName
                                      : 'Total Spent',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedCategory != null
                                        ? _selectedCategory!.color
                                        : Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedCategory != null
                                      ? CurrencyFormatter.formatVND(
                                          widget.data[_selectedCategory!] ?? 0.0)
                                      : CurrencyFormatter.formatVND(total),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (_selectedCategory != null && total > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      '${(((widget.data[_selectedCategory!] ?? 0) / total) * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedCategory!.color,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // Interactive Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: widget.data.entries.where((e) => e.value > 0).map((entry) {
            final isSelected = _selectedCategory == entry.key;
            final percentage = total > 0 ? (entry.value / total * 100) : 0.0;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = isSelected ? null : entry.key;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? entry.key.color.withOpacity(0.15)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? entry.key.color : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: entry.key.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.key.vietnameseName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final Map<ExpenseCategory, double> data;
  final double total;
  final double progress;
  final ExpenseCategory? selectedCategory;

  _DonutChartPainter({
    required this.data,
    required this.total,
    required this.progress,
    this.selectedCategory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2 - 16;
    const strokeWidth = 26.0;

    // Draw background track ring
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, baseRadius, bgPaint);

    if (total <= 0) return;

    var startAngle = -math.pi / 2; // start from 12 o'clock
    const gapAngle = 0.04; // small aesthetic gap between slices

    for (final entry in data.entries) {
      final value = entry.value;
      if (value <= 0) continue;

      final isSelected = selectedCategory == entry.key;
      final fullSweepAngle = (value / total) * 2 * math.pi;
      final sweepAngle = (fullSweepAngle - gapAngle) * progress;

      if (sweepAngle <= 0) continue;

      final effectiveRadius = isSelected ? baseRadius + 4 : baseRadius;
      final effectiveStroke = isSelected ? strokeWidth + 6 : strokeWidth;

      final paint = Paint()
        ..color = entry.key.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveStroke
        ..strokeCap = StrokeCap.round;

      // Draw subtle shadow for selected slice
      if (isSelected) {
        final shadowPaint = Paint()
          ..color = entry.key.color.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = effectiveStroke + 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: effectiveRadius),
          startAngle + (gapAngle / 2),
          sweepAngle,
          false,
          shadowPaint,
        );
      }

      // Draw arc on canvas
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: effectiveRadius),
        startAngle + (gapAngle / 2),
        sweepAngle,
        false,
        paint,
      );

      startAngle += fullSweepAngle * progress;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.total != total ||
        oldDelegate.data != data;
  }
}

