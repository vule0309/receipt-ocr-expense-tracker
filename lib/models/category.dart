import 'package:flutter/material.dart';

/// Categories required by Mini-Project 3 specification:
/// Food, Study, Travel, Gear, Entertainment
enum ExpenseCategory {
  food,
  study,
  travel,
  gear,
  entertainment,
}

extension ExpenseCategoryExtension on ExpenseCategory {
  String get id {
    switch (this) {
      case ExpenseCategory.food:
        return 'food';
      case ExpenseCategory.study:
        return 'study';
      case ExpenseCategory.travel:
        return 'travel';
      case ExpenseCategory.gear:
        return 'gear';
      case ExpenseCategory.entertainment:
        return 'entertainment';
    }
  }

  String get displayName {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food & Dining';
      case ExpenseCategory.study:
        return 'Study & Books';
      case ExpenseCategory.travel:
        return 'Travel & Transit';
      case ExpenseCategory.gear:
        return 'Gear & Tech';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
    }
  }

  String get vietnameseName {
    switch (this) {
      case ExpenseCategory.food:
        return 'Ăn uống';
      case ExpenseCategory.study:
        return 'Học tập';
      case ExpenseCategory.travel:
        return 'Di chuyển';
      case ExpenseCategory.gear:
        return 'Thiết bị & Đồ dùng';
      case ExpenseCategory.entertainment:
        return 'Giải trí';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.study:
        return Icons.menu_book_rounded;
      case ExpenseCategory.travel:
        return Icons.directions_car_rounded;
      case ExpenseCategory.gear:
        return Icons.devices_rounded;
      case ExpenseCategory.entertainment:
        return Icons.sports_esports_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.food:
        return const Color(0xFFFF6B6B); // Vibrant Coral
      case ExpenseCategory.study:
        return const Color(0xFF4D96FF); // Academic Blue
      case ExpenseCategory.travel:
        return const Color(0xFF6BCB77); // Fresh Mint/Teal
      case ExpenseCategory.gear:
        return const Color(0xFF9D4EDD); // Modern Purple
      case ExpenseCategory.entertainment:
        return const Color(0xFFFFB703); // Energetic Amber
    }
  }

  static ExpenseCategory fromString(String? value) {
    if (value == null) return ExpenseCategory.food;
    final lower = value.toLowerCase().trim();
    for (final cat in ExpenseCategory.values) {
      if (cat.name.toLowerCase() == lower ||
          cat.displayName.toLowerCase() == lower ||
          cat.vietnameseName.toLowerCase() == lower) {
        return cat;
      }
    }
    return ExpenseCategory.food;
  }
}
