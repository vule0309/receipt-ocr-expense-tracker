import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_expense_tracker/services/receipt_heuristic_parser.dart';
import 'package:ocr_expense_tracker/utils/currency_formatter.dart';
import 'package:ocr_expense_tracker/models/category.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('Format VND correctly', () {
      expect(CurrencyFormatter.formatVND(150000), contains('150.000'));
      expect(CurrencyFormatter.formatCompact(150000), '150k');
      expect(CurrencyFormatter.formatCompact(1500000), '1.5M');
    });

    test('Parse various currency strings', () {
      expect(CurrencyFormatter.parseAmount('150.000 đ'), 150000);
      expect(CurrencyFormatter.parseAmount('150,000 VND'), 150000);
      expect(CurrencyFormatter.parseAmount('215.000'), 215000);
      expect(CurrencyFormatter.parseAmount('150k'), 150000);
      expect(CurrencyFormatter.parseAmount('1.5M'), 1500000);
      expect(CurrencyFormatter.parseAmount('Tổng cộng: 350.000'), 350000);
    });
  });

  group('ReceiptHeuristicParser Regex Tests', () {
    test('Parses WinMart Supermarket receipt correctly', () {
      const receiptText = '''
SIÊU THỊ WINMART
Đ/c: TTTM Vincom Plaza, Đà Nẵng
ĐT: 0236.3888999
HÓA ĐƠN BÁN HÀNG
Ngày: 12/10/2026 09:45
01 Sữa tươi      2   72.000
02 Bánh mì       1   25.000
03 Táo Envy 1kg  1  118.000
Cộng tiền hàng: 215.000
Thuế VAT (8%): 17.200
TỔNG CỘNG: 215.000 VND
Tiền khách đưa: 500.000
Tiền thừa: 285.000
''';

      final parsed = ReceiptHeuristicParser.parse(receiptText);

      expect(parsed.merchant, contains('WinMart'));
      expect(parsed.totalAmount, 215000);
      expect(parsed.suggestedCategory, ExpenseCategory.food);
      expect(parsed.date?.day, 12);
      expect(parsed.date?.month, 10);
      expect(parsed.date?.year, 2026);
      expect(parsed.overallConfidence, greaterThan(0.8));
    });

    test('Parses Highlands Coffee receipt correctly without confusing change/tiền thối', () {
      const receiptText = '''
HIGHLANDS COFFEE
Chi nhánh Bạch Đằng
HÓA ĐƠN THANH TOÁN
Date: 11/10/2026 15:20
1. Trà sen vàng (L)    1    55.000
2. Freeze Trà Xanh (M) 1    65.000
3. Bánh chuối          1    29.000
THANH TOÁN: 149.000 đ
Tiền mặt nhận: 200.000
Tiền thối: 51.000
''';

      final parsed = ReceiptHeuristicParser.parse(receiptText);

      expect(parsed.merchant, contains('Highlands Coffee'));
      expect(parsed.totalAmount, 149000); // must NOT be 51.000 or 200.000!
      expect(parsed.suggestedCategory, ExpenseCategory.food);
      expect(parsed.date?.day, 11);
      expect(parsed.date?.month, 10);
      expect(parsed.date?.year, 2026);
    });

    test('Parses Fahasa Bookstore receipt with Study category', () {
      const receiptText = '''
NHÀ SÁCH FAHASA
Địa chỉ: Lê Duẩn, Đà Nẵng
PHIẾU THANH TOÁN
Ngày mua: 10/10/2026 17:30
- Sách Lập trình di động  1  185.000
- Vở kẻ ngang            5   75.000
- Bút bi Thiên Long      3   30.000
Tổng tiền: 290.000 VND
Thanh toán: 290.000 VND
''';

      final parsed = ReceiptHeuristicParser.parse(receiptText);

      expect(parsed.merchant, contains('Fahasa'));
      expect(parsed.totalAmount, 290000);
      expect(parsed.suggestedCategory, ExpenseCategory.study);
      expect(parsed.date?.day, 10);
      expect(parsed.date?.month, 10);
    });

    test('Parses CellphoneS receipt with Gear category', () {
      const receiptText = '''
HỆ THỐNG CELLPHONES
Ngày lập: 08/10/2026 14:15
Chuột Logitech M331     1   350.000
Cáp sạc Type-C Anker    1   190.000
Lót chuột Gaming Razer  1   150.000
TỔNG THANH TOÁN: 640.000 VND
''';

      final parsed = ReceiptHeuristicParser.parse(receiptText);

      expect(parsed.merchant, contains('CellphoneS'));
      expect(parsed.totalAmount, 640000);
      expect(parsed.suggestedCategory, ExpenseCategory.gear);
    });

    test('Parses GrabBike receipt with Travel category', () {
      const receiptText = '''
GRAB VIETNAM
Chuyến xe GrabBike
Ngày: 09/10/2026 18:00
Cước phí: 42.000
Phí nền tảng: 3.000
TỔNG CỘNG: 45.000 VND
''';

      final parsed = ReceiptHeuristicParser.parse(receiptText);

      expect(parsed.merchant, contains('Grab'));
      expect(parsed.totalAmount, 45000);
      expect(parsed.suggestedCategory, ExpenseCategory.travel);
    });
  });
}

