import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryBadge extends StatelessWidget {
  final ExpenseCategory category;
  final bool showIcon;
  final double fontSize;

  const CategoryBadge({
    super.key,
    required this.category,
    this.showIcon = true,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: category.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: category.color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(category.icon, size: fontSize + 2, color: category.color),
            const SizedBox(width: 4),
          ],
          Text(
            category.displayName,
            style: TextStyle(
              color: category.color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

