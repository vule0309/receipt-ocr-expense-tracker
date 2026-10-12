import '../models/category.dart';
import '../models/parsed_receipt.dart';
import '../utils/currency_formatter.dart';

class ReceiptHeuristicParser {
  /// Known popular merchants in Vietnam & global chains with their typical categories
  static final Map<String, ExpenseCategory> _knownMerchants = {
    // Food & Dining / Supermarkets
    'WinMart': ExpenseCategory.food,
    'WinMart+': ExpenseCategory.food,
    'Co.opmart': ExpenseCategory.food,
    'Co.op Food': ExpenseCategory.food,
    'Bách Hóa Xanh': ExpenseCategory.food,
    'Bach Hoa Xanh': ExpenseCategory.food,
    'Big C': ExpenseCategory.food,
    'GO!': ExpenseCategory.food,
    'Lotte Mart': ExpenseCategory.food,
    'Aeon Mall': ExpenseCategory.food,
    'Circle K': ExpenseCategory.food,
    'FamilyMart': ExpenseCategory.food,
    '7-Eleven': ExpenseCategory.food,
    'Ministop': ExpenseCategory.food,
    'GS25': ExpenseCategory.food,
    'Highlands Coffee': ExpenseCategory.food,
    'Phúc Long': ExpenseCategory.food,
    'Phuc Long': ExpenseCategory.food,
    'The Coffee House': ExpenseCategory.food,
    'Trung Nguyên': ExpenseCategory.food,
    'Trung Nguyen': ExpenseCategory.food,
    'Gong Cha': ExpenseCategory.food,
    'Koi Thé': ExpenseCategory.food,
    'TocoToco': ExpenseCategory.food,
    'Starbucks': ExpenseCategory.food,
    'Phê La': ExpenseCategory.food,
    'Katinat': ExpenseCategory.food,
    'KFC': ExpenseCategory.food,
    'Lotteria': ExpenseCategory.food,
    'Jollibee': ExpenseCategory.food,
    'McDonald\'s': ExpenseCategory.food,
    'Pizza Hut': ExpenseCategory.food,
    'Domino\'s Pizza': ExpenseCategory.food,
    'The Pizza Company': ExpenseCategory.food,
    'Haidilao': ExpenseCategory.food,
    'Kichi Kichi': ExpenseCategory.food,
    'Gogi House': ExpenseCategory.food,
    'King BBQ': ExpenseCategory.food,

    // Study & Stationery
    'Nhà Sách Fahasa': ExpenseCategory.study,
    'Fahasa': ExpenseCategory.study,
    'Nhà Sách Phương Nam': ExpenseCategory.study,
    'Phương Nam Book': ExpenseCategory.study,
    'Nhà Sách Tiền Phong': ExpenseCategory.study,
    'Nhà Sách Cá Chép': ExpenseCategory.study,
    'Văn Phòng Phẩm': ExpenseCategory.study,
    'In Ấn Photocopy': ExpenseCategory.study,

    // Travel & Transit
    'Grab': ExpenseCategory.travel,
    'Be Group': ExpenseCategory.travel,
    'Xanh SM': ExpenseCategory.travel,
    'Mai Linh Taxi': ExpenseCategory.travel,
    'Vinasun Taxi': ExpenseCategory.travel,
    'Petrolimex': ExpenseCategory.travel,
    'PV Oil': ExpenseCategory.travel,
    'Cây Xăng': ExpenseCategory.travel,
    'Vé Xe Phương Trang': ExpenseCategory.travel,

    // Gear & Tech
    'Thế Giới Di Động': ExpenseCategory.gear,
    'Điện Máy Xanh': ExpenseCategory.gear,
    'FPT Shop': ExpenseCategory.gear,
    'CellphoneS': ExpenseCategory.gear,
    'Hoàng Hà Mobile': ExpenseCategory.gear,
    'GearVN': ExpenseCategory.gear,
    'Phong Vũ': ExpenseCategory.gear,
    'An Phát Computer': ExpenseCategory.gear,
    'Hacom': ExpenseCategory.gear,

    // Entertainment
    'CGV Cinemas': ExpenseCategory.entertainment,
    'BHD Star': ExpenseCategory.entertainment,
    'Lotte Cinema': ExpenseCategory.entertainment,
    'Galaxy Cinema': ExpenseCategory.entertainment,
    'Beta Cinemas': ExpenseCategory.entertainment,
    'Timezone': ExpenseCategory.entertainment,
  };

  /// Main method to parse raw OCR text and return structured ParsedReceipt
  static ParsedReceipt parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return ParsedReceipt(
        rawText: rawText,
        suggestedCategory: ExpenseCategory.food,
        overallConfidence: 0.0,
      );
    }

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Extract Merchant Name
    final merchantResult = _extractMerchant(lines);

    // 2. Extract Total Amount
    final amountResult = _extractTotalAmount(lines);

    // 3. Extract Transaction Date
    final dateResult = _extractDate(lines);

    // 4. Infer Category
    final category = _inferCategory(
      merchant: merchantResult.value,
      lines: lines,
    );

    // 5. Extract Line Items (heuristic item rows)
    final lineItems = _extractLineItems(lines);

    // Compute field confidences
    final fieldConfidences = {
      'merchant': merchantResult.confidence,
      'amount': amountResult.confidence,
      'date': dateResult.confidence,
      'category': merchantResult.confidence > 0.8 ? 0.9 : 0.7,
    };

    final overallConfidence = (merchantResult.confidence * 0.35 +
            amountResult.confidence * 0.45 +
            dateResult.confidence * 0.20)
        .clamp(0.0, 1.0);

    return ParsedReceipt(
      rawText: rawText,
      merchant: merchantResult.value,
      totalAmount: amountResult.value,
      date: dateResult.value,
      suggestedCategory: category,
      overallConfidence: overallConfidence,
      lineItems: lineItems,
      fieldConfidences: fieldConfidences,
      extractedCandidates: amountResult.candidates,
    );
  }

  // ==========================================
  // 1. MERCHANT NAME EXTRACTION
  // ==========================================
  static _ParserMatch<String?> _extractMerchant(List<String> lines) {
    final lowerText = lines.join(' ').toLowerCase();

    // 1. Exact or partial match with known merchant brand
    for (final entry in _knownMerchants.entries) {
      final brand = entry.key;
      final brandLower = brand.toLowerCase();
      if (lowerText.contains(brandLower)) {
        return _ParserMatch(brand, 0.95);
      }
    }

    // 2. Scan top 5 lines for store name candidates
    final ignoredPatterns = RegExp(
      r'^(hóa đơn|phiếu|receipt|bill|invoice|tax|cộng hòa|độc lập|ngày|date|địa chỉ|address|tel|đt|sđt|phone|mst|fax|stt|www|\d+)',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length && i < 6; i++) {
      final line = lines[i];
      if (line.length < 3 || line.length > 50) continue;
      if (ignoredPatterns.hasMatch(line)) continue;
      if (line.contains('@') || line.contains('.vn') || line.contains('.com')) continue;
      // If line contains mostly alphabets and upper case words
      final alphaCount = line.replaceAll(RegExp(r'[^a-zA-ZÀ-ỹ\s]'), '').length;
      if (alphaCount > line.length * 0.6) {
        return _ParserMatch(line, 0.75);
      }
    }

    return _ParserMatch(lines.isNotEmpty ? lines[0] : null, 0.4);
  }

  // ==========================================
  // 2. TOTAL AMOUNT EXTRACTION
  // ==========================================
  static _ParserAmountResult _extractTotalAmount(List<String> lines) {
    final candidates = <String>[];

    // Priority 1: Lines containing explicit TOTAL keywords
    // Keywords in Vietnamese and English:
    final totalKeywords = RegExp(
      r'(tổng\s*cộng|tong\s*cong|tổng\s*tiền|tong\s*tien|thanh\s*toán|thanh\s*toan|phải\s*trả|phai\s*tra|tổng\s*chi|total\s*due|grand\s*total|net\s*total|amount\s*due|total\b)',
      caseSensitive: false,
    );

    // Negative keywords to explicitly exclude (e.g. cash received, change/tiền thừa, discount)
    final negativeKeywords = RegExp(
      r'(tiền\s*thối|tiền\s*thừa|tien\s*thua|tiền\s*khách\s*đưa|khach\s*dua|tiền\s*mặt\s*nhận|cash\s*tendered|change\s*due|chiết\s*khấu|giảm\s*giá|discount)',
      caseSensitive: false,
    );

    // Subtotal keywords (fallback if no grand total)
    final subtotalKeywords = RegExp(
      r'(tiền\s*hàng|cộng\s*tiền|subtotal)',
      caseSensitive: false,
    );

    double? totalFound;
    double? subtotalFound;

    // Pattern to grab currency numbers like 150,000 or 150.000 or 1,250,000 or 150000
    final numberPattern = RegExp(r'(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d+)?|\d{4,})');

    for (final line in lines) {
      if (negativeKeywords.hasMatch(line)) {
        continue; // skip change / customer cash lines
      }

      if (totalKeywords.hasMatch(line)) {
        final matches = numberPattern.allMatches(line);
        for (final m in matches) {
          final matchedStr = m.group(0)!;
          final parsed = CurrencyFormatter.parseAmount(matchedStr);
          if (parsed != null && parsed > 500 && parsed < 1000000000) {
            candidates.add('$matchedStr (from "$line")');
            totalFound = parsed;
            // Often the last match on a total line is the final amount
          }
        }
      } else if (subtotalKeywords.hasMatch(line) && subtotalFound == null) {
        final matches = numberPattern.allMatches(line);
        for (final m in matches) {
          final matchedStr = m.group(0)!;
          final parsed = CurrencyFormatter.parseAmount(matchedStr);
          if (parsed != null && parsed > 500 && parsed < 1000000000) {
            candidates.add('$matchedStr (subtotal "$line")');
            subtotalFound = parsed;
          }
        }
      }
    }

    if (totalFound != null) {
      return _ParserAmountResult(totalFound, 0.95, candidates);
    }

    if (subtotalFound != null) {
      return _ParserAmountResult(subtotalFound, 0.80, candidates);
    }

    // Priority 2: Numbers followed by currency markers (e.g. 150.000 đ, 150,000 VND)
    final currencyPattern = RegExp(
      r'(\d{1,3}(?:[.,]\d{3})+|\d{4,})\s*(?:vnd|vnđ|đ|d\b)',
      caseSensitive: false,
    );

    double maxCurrencyAmount = 0.0;
    for (final line in lines) {
      if (negativeKeywords.hasMatch(line)) continue;
      final match = currencyPattern.firstMatch(line);
      if (match != null) {
        final valStr = match.group(1)!;
        final parsed = CurrencyFormatter.parseAmount(valStr);
        if (parsed != null && parsed > maxCurrencyAmount && parsed < 1000000000) {
          maxCurrencyAmount = parsed;
          candidates.add('$valStr (with currency marker)');
        }
      }
    }

    if (maxCurrencyAmount > 0) {
      return _ParserAmountResult(maxCurrencyAmount, 0.75, candidates);
    }

    // Priority 3: Fallback heuristic - largest reasonable amount in bottom 60% of receipt
    final startIndex = (lines.length * 0.4).floor();
    double fallbackMax = 0.0;
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      if (negativeKeywords.hasMatch(line)) continue;
      // Exclude phone numbers, dates, tax codes (MST often 10 digits without punctuation)
      if (line.contains(RegExp(r'\b(mst|tel|phone|fax)\b', caseSensitive: false))) continue;

      final matches = numberPattern.allMatches(line);
      for (final m in matches) {
        final str = m.group(0)!;
        // Avoid phone numbers or 10-digit continuous numbers
        if (str.length == 10 && !str.contains('.') && !str.contains(',')) continue;
        final parsed = CurrencyFormatter.parseAmount(str);
        if (parsed != null && parsed >= 1000 && parsed <= 50000000 && parsed > fallbackMax) {
          fallbackMax = parsed;
          candidates.add('$str (fallback)');
        }
      }
    }

    if (fallbackMax > 0) {
      return _ParserAmountResult(fallbackMax, 0.50, candidates);
    }

    return _ParserAmountResult(null, 0.0, candidates);
  }

  // ==========================================
  // 3. DATE EXTRACTION
  // ==========================================
  static _ParserMatch<DateTime?> _extractDate(List<String> lines) {
    // Standard formats:
    // DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
    // YYYY-MM-DD
    // DD/MM/YY
    final dateWithKeyword = RegExp(
      r'(ngày|ngay|date|time|giờ|gio|tg\s*:)?\s*(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})',
      caseSensitive: false,
    );

    final isoDatePattern = RegExp(
      r'(\d{4})[\/\.\-](\d{1,2})[\/\.\-](\d{1,2})',
    );

    // First scan for lines with "ngày" / "date"
    for (final line in lines) {
      final match = dateWithKeyword.firstMatch(line);
      if (match != null) {
        final p1 = int.tryParse(match.group(2) ?? '');
        final p2 = int.tryParse(match.group(3) ?? '');
        var p3 = int.tryParse(match.group(4) ?? '');

        if (p1 != null && p2 != null && p3 != null) {
          // Fix 2-digit year (e.g. 26 -> 2026)
          if (p3 < 100) {
            p3 += 2000;
          }

          final day = p1;
          final month = p2;
          final year = p3;

          if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 2020 && year <= 2035) {
            final hasKeyword = match.group(1) != null;
            return _ParserMatch(
              DateTime(year, month, day),
              hasKeyword ? 0.95 : 0.85,
            );
          }
        }
      }

      // Check ISO format YYYY-MM-DD
      final isoMatch = isoDatePattern.firstMatch(line);
      if (isoMatch != null) {
        final year = int.tryParse(isoMatch.group(1) ?? '');
        final month = int.tryParse(isoMatch.group(2) ?? '');
        final day = int.tryParse(isoMatch.group(3) ?? '');
        if (year != null && month != null && day != null) {
          if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 2020 && year <= 2035) {
            return _ParserMatch(DateTime(year, month, day), 0.90);
          }
        }
      }
    }

    return _ParserMatch(null, 0.0);
  }

  // ==========================================
  // 4. CATEGORY INFERENCE
  // ==========================================
  static ExpenseCategory _inferCategory({
    String? merchant,
    required List<String> lines,
  }) {
    if (merchant != null && _knownMerchants.containsKey(merchant)) {
      return _knownMerchants[merchant]!;
    }

    final fullText = lines.join(' ').toLowerCase();

    // Check Study keywords
    if (RegExp(r'(sách|sach|vở|vo|bút|but|nhà sách|fahasa|phương nam|học phí|hoc phi|giáo trình|tài liệu|in ấn|photocopy|stationery|study)').hasMatch(fullText)) {
      return ExpenseCategory.study;
    }

    // Check Travel keywords
    if (RegExp(r'(grab|be\b|xanh sm|taxi|xăng|xang|petrol|pv oil|vé xe|ve xe|gửi xe|gui xe|parking|vé tàu|ve tau|vé máy bay|fuel|transit)').hasMatch(fullText)) {
      return ExpenseCategory.travel;
    }

    // Check Gear keywords
    if (RegExp(r'(thế giới di động|tgdd|fpt|cellphones|hoàng hà|gearvn|phong vũ|an phát|chuột|bàn phím|tai nghe|cáp|sạc|laptop|linh kiện|điện thoại|phụ kiện|usb|màn hình|ram|ssd)').hasMatch(fullText)) {
      return ExpenseCategory.gear;
    }

    // Check Entertainment keywords
    if (RegExp(r'(cgv|bhd|lotte cinema|galaxy cinema|rạp chiếu|rap chieu|vé xem phim|game|billiards|karaoke|bowling|steam|playstation|nintendo|netflix|spotify|nhạc|ticket)').hasMatch(fullText)) {
      return ExpenseCategory.entertainment;
    }

    // Check Food keywords
    if (RegExp(r'(cafe|cà phê|trà sữa|tra sua|coffee|food|mart|coop|winmart|siêu thị|bách hóa|ăn|cơm|bún|phở|bánh|gà rán|pizza|lẩu|nướng|highlands|phuc long|circle k|lotteria|kfc|jollibee|restaurant|quán|quán ăn)').hasMatch(fullText)) {
      return ExpenseCategory.food;
    }

    return ExpenseCategory.food;
  }

  // ==========================================
  // 5. LINE ITEMS EXTRACTION (BONUS HEURISTIC)
  // ==========================================
  static List<ReceiptLineItem> _extractLineItems(List<String> lines) {
    final items = <ReceiptLineItem>[];
    final itemPattern = RegExp(
      r'^([A-Za-zÀ-ỹ0-9\s\.\-]{3,30})\s+(\d+)\s+([0-9.,]+)$',
    );

    for (final line in lines) {
      final match = itemPattern.firstMatch(line.trim());
      if (match != null) {
        final name = match.group(1)!.trim();
        final qty = int.tryParse(match.group(2)!) ?? 1;
        final price = CurrencyFormatter.parseAmount(match.group(3)!) ?? 0.0;
        if (price > 0 && !name.toLowerCase().contains('tổng') && !name.toLowerCase().contains('total')) {
          items.add(ReceiptLineItem(
            name: name,
            quantity: qty,
            unitPrice: price / (qty > 0 ? qty : 1),
            totalPrice: price,
          ));
        }
      }
    }
    return items;
  }
}

class _ParserMatch<T> {
  final T value;
  final double confidence;

  _ParserMatch(this.value, this.confidence);
}

class _ParserAmountResult {
  final double? value;
  final double confidence;
  final List<String> candidates;

  _ParserAmountResult(this.value, this.confidence, this.candidates);
}

