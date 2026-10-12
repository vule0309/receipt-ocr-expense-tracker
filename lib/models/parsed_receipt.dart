import 'category.dart';

/// Represents a single itemized row on a receipt
class ReceiptLineItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const ReceiptLineItem({
    required this.name,
    this.quantity = 1,
    required this.unitPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  factory ReceiptLineItem.fromMap(Map<String, dynamic> map) {
    return ReceiptLineItem(
      name: map['name'] as String? ?? 'Item',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// The result returned by the Heuristic Regex Receipt Parser
class ParsedReceipt {
  final String rawText;
  final String? merchant;
  final double? totalAmount;
  final DateTime? date;
  final ExpenseCategory suggestedCategory;
  final double overallConfidence;
  final List<ReceiptLineItem> lineItems;
  final Map<String, double> fieldConfidences;
  final List<String> extractedCandidates; // for debug & suggestions

  ParsedReceipt({
    required this.rawText,
    this.merchant,
    this.totalAmount,
    this.date,
    required this.suggestedCategory,
    this.overallConfidence = 0.0,
    this.lineItems = const [],
    this.fieldConfidences = const {},
    this.extractedCandidates = const [],
  });
}

