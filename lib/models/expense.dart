import 'dart:convert';
import 'category.dart';
import 'parsed_receipt.dart';

class ExpenseItem {
  final int? id;
  final String merchant;
  final double amount;
  final DateTime date;
  final ExpenseCategory category;
  final String? note;
  final String? rawOcrText;
  final String? imagePath;
  final String? thumbnailPath;
  final double confidence;
  final List<ReceiptLineItem> lineItems;
  final DateTime createdAt;

  ExpenseItem({
    this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    this.note,
    this.rawOcrText,
    this.imagePath,
    this.thumbnailPath,
    this.confidence = 1.0,
    this.lineItems = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant': merchant,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category.name,
      'note': note,
      'rawOcrText': rawOcrText,
      'imagePath': imagePath,
      'thumbnailPath': thumbnailPath,
      'confidence': confidence,
      'lineItems': jsonEncode(lineItems.map((e) => e.toMap()).toList()),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    List<ReceiptLineItem> items = [];
    if (map['lineItems'] != null && map['lineItems'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['lineItems'] as String) as List<dynamic>;
        items = decoded
            .map((e) => ReceiptLineItem.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return ExpenseItem(
      id: map['id'] as int?,
      merchant: map['merchant'] as String? ?? 'Unknown Merchant',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      category: ExpenseCategoryExtension.fromString(map['category'] as String?),
      note: map['note'] as String?,
      rawOcrText: map['rawOcrText'] as String?,
      imagePath: map['imagePath'] as String?,
      thumbnailPath: map['thumbnailPath'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      lineItems: items,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  ExpenseItem copyWith({
    int? id,
    String? merchant,
    double? amount,
    DateTime? date,
    ExpenseCategory? category,
    String? note,
    String? rawOcrText,
    String? imagePath,
    String? thumbnailPath,
    double? confidence,
    List<ReceiptLineItem>? lineItems,
    DateTime? createdAt,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      note: note ?? this.note,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      confidence: confidence ?? this.confidence,
      lineItems: lineItems ?? this.lineItems,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

