import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/parsed_receipt.dart';
import '../services/database_helper.dart';
import '../services/thumbnail_service.dart';
import '../utils/currency_formatter.dart';

class ReceiptReviewScreen extends StatefulWidget {
  final File? receiptImage;
  final ParsedReceipt parsedReceipt;

  const ReceiptReviewScreen({
    super.key,
    this.receiptImage,
    required this.parsedReceipt,
  });

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  late ExpenseCategory _selectedCategory;
  late List<ReceiptLineItem> _lineItems;

  bool _isSaving = false;
  bool _showRawOcr = false;

  @override
  void initState() {
    super.initState();
    final parsed = widget.parsedReceipt;

    _merchantController = TextEditingController(text: parsed.merchant ?? '');
    _amountController = TextEditingController(
      text: parsed.totalAmount != null
          ? CurrencyFormatter.formatVND(parsed.totalAmount!).replaceAll('₫', '').trim()
          : '',
    );
    _noteController = TextEditingController();
    _selectedDate = parsed.date ?? DateTime.now();
    _selectedCategory = parsed.suggestedCategory;
    _lineItems = List.from(parsed.lineItems);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _selectedCategory.color,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = CurrencyFormatter.parseAmount(_amountController.text);
    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? imagePath;
      String? thumbPath;

      if (widget.receiptImage != null && await widget.receiptImage!.exists()) {
        final cached = await ThumbnailService.instance.processAndCacheReceipt(
          widget.receiptImage!,
        );
        imagePath = cached.imagePath;
        thumbPath = cached.thumbnailPath;
      }

      final expense = ExpenseItem(
        merchant: _merchantController.text.trim().isEmpty
            ? 'General Expense'
            : _merchantController.text.trim(),
        amount: parsedAmount,
        date: _selectedDate,
        category: _selectedCategory,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        rawOcrText: widget.parsedReceipt.rawText,
        imagePath: imagePath,
        thumbnailPath: thumbPath,
        confidence: widget.parsedReceipt.overallConfidence,
        lineItems: _lineItems,
      );

      await DatabaseHelper.instance.insertExpense(expense);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved expense: ${CurrencyFormatter.formatVND(parsedAmount)}'),
          backgroundColor: Colors.green.shade700,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving expense: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final confidencePercent = (widget.parsedReceipt.overallConfidence * 100).toInt();
    final confidenceColor = confidencePercent >= 80
        ? Colors.green
        : (confidencePercent >= 50 ? Colors.orange : Colors.red);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Receipt'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showRawOcr ? Icons.code_off : Icons.code),
            tooltip: 'Toggle Raw OCR Diagnostics',
            onPressed: () => setState(() => _showRawOcr = !_showRawOcr),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Receipt Thumbnail & AI Confidence Header
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      // Image Preview or Icon
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: widget.receiptImage != null
                            ? Image.file(
                                widget.receiptImage!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 64,
                                height: 64,
                                color: _selectedCategory.color.withOpacity(0.15),
                                child: Icon(
                                  _selectedCategory.icon,
                                  color: _selectedCategory.color,
                                  size: 32,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: confidenceColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome, size: 13, color: confidenceColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ML Kit AI $confidencePercent%',
                                        style: TextStyle(
                                          color: confidenceColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Offline OCR',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _merchantController.text.isNotEmpty
                                  ? _merchantController.text
                                  : 'Scanned Receipt',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Total Amount Input Field (Highlighted)
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Total Amount (Số tiền)',
                  suffixText: '₫',
                  suffixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter total amount';
                  }
                  if (CurrencyFormatter.parseAmount(val) == null) {
                    return 'Invalid number format';
                  }
                  return null;
                },
              ),

              // Suggestion Candidates Chips (if OCR detected multiple numbers)
              if (widget.parsedReceipt.extractedCandidates.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Text(
                    'OCR Candidates:',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.parsedReceipt.extractedCandidates.take(5).map((cand) {
                      final val = CurrencyFormatter.parseAmount(cand);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ActionChip(
                          avatar: const Icon(Icons.tag, size: 14),
                          label: Text(
                            val != null ? CurrencyFormatter.formatVND(val) : cand,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            if (val != null) {
                              setState(() {
                                _amountController.text = CurrencyFormatter.formatVND(val)
                                    .replaceAll('₫', '')
                                    .trim();
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 3. Merchant Name Field
              TextFormField(
                controller: _merchantController,
                decoration: InputDecoration(
                  labelText: 'Merchant / Store Name',
                  prefixIcon: const Icon(Icons.store_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter merchant name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 4. Transaction Date Picker
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: Colors.grey),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transaction Date', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          Text(
                            DateFormat('EEEE, dd/MM/yyyy').format(_selectedDate),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 5. Category Selection Chips
              const Text(
                'Expense Category',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    avatar: Icon(
                      cat.icon,
                      size: 16,
                      color: isSelected ? Colors.white : cat.color,
                    ),
                    label: Text(cat.displayName),
                    selected: isSelected,
                    selectedColor: cat.color,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = cat);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // 6. Optional Note Field
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  hintText: 'e.g. Group lunch, books for Project 3...',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              // 7. Expandable Line Items (if parsed)
              if (_lineItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: Text(
                      'Detected Items (${_lineItems.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _lineItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _lineItems[index];
                          return ListTile(
                            dense: true,
                            title: Text(item.name),
                            subtitle: Text('Qty: ${item.quantity}'),
                            trailing: Text(
                              CurrencyFormatter.formatVND(item.totalPrice),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // 8. Raw OCR Diagnostics Panel
              if (_showRawOcr) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Raw OCR Text (On-Device ML Kit)',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${widget.parsedReceipt.rawText.length} chars',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.grey),
                      SelectableText(
                        widget.parsedReceipt.rawText.isEmpty
                            ? '(No text extracted)'
                            : widget.parsedReceipt.rawText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Save Button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: _selectedCategory.color,
                  foregroundColor: Colors.white,
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Expense',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

