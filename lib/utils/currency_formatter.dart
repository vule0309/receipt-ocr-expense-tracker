import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _vndFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );


  /// Format as 150.000 ₫
  static String formatVND(double amount) {
    try {
      return _vndFormat.format(amount);
    } catch (_) {
      final whole = amount.round().toString();
      final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
      return '${whole.replaceAll(reg, '.') } ₫';
    }
  }

  /// Compact format for chart axes (e.g., 150k ₫ or 1.2M ₫)
  static String formatCompact(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toStringAsFixed(0);
  }

  /// Parse string like "150,000", "150.000 đ", "150k" to double
  static double? parseAmount(String input) {
    if (input.trim().isEmpty) return null;
    var cleaned = input.toLowerCase().trim();
    cleaned = cleaned.replaceAll('vnd', '').replaceAll('vnđ', '').replaceAll('đ', '').replaceAll('d', '');
    cleaned = cleaned.replaceAll('tong cong', '').replaceAll('total', '').replaceAll('thanh toan', '');
    cleaned = cleaned.trim();

    // Check shorthand like 150k or 1.5m
    if (cleaned.endsWith('k')) {
      final numStr = cleaned.substring(0, cleaned.length - 1).replaceAll(',', '.').trim();
      final val = double.tryParse(numStr);
      if (val != null) return val * 1000;
    }
    if (cleaned.endsWith('m') || cleaned.endsWith('tr')) {
      final numStr = cleaned.replaceAll('m', '').replaceAll('tr', '').replaceAll(',', '.').trim();
      final val = double.tryParse(numStr);
      if (val != null) return val * 1000000;
    }

    // Standard Vietnamese: 150.000 or English: 150,000
    // If it contains both '.' and ',' (e.g. 1,250.50 or 1.250,50)
    if (cleaned.contains('.') && cleaned.contains(',')) {
      if (cleaned.lastIndexOf('.') > cleaned.lastIndexOf(',')) {
        // 1,234.56
        cleaned = cleaned.replaceAll(',', '');
      } else {
        // 1.234,56
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (cleaned.contains('.')) {
      // Could be thousands separator (150.000) or decimal (15.50)
      final parts = cleaned.split('.');
      if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
        // Thousands separator
        cleaned = cleaned.replaceAll('.', '');
      }
    } else if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
        // Thousands separator
        cleaned = cleaned.replaceAll(',', '');
      } else {
        cleaned = cleaned.replaceAll(',', '.');
      }
    }

    // Strip any remaining spaces or non-digit chars except dot
    cleaned = cleaned.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned);
  }
}

