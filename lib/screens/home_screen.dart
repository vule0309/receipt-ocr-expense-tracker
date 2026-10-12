import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../services/database_helper.dart';
import '../widgets/summary_card.dart';
import '../widgets/expense_list_tile.dart';
import 'camera_screen.dart';
import 'analytics_screen.dart';
import 'expense_detail_screen.dart';
import 'receipt_review_screen.dart';
import '../models/parsed_receipt.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<ExpenseItem> _expenses = [];
  double _totalSpending = 0.0;
  bool _isLoading = true;

  ExpenseCategory? _selectedCategoryFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // Seed initial mock receipts if database is completely empty for immediate out-of-the-box demo
    await DatabaseHelper.instance.seedMockDataIfEmpty();
    await _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final expenses = await DatabaseHelper.instance.getExpenses(
      category: _selectedCategoryFilter,
      searchQuery: _searchController.text.trim(),
    );
    final total = await DatabaseHelper.instance.getTotalSpending();

    if (mounted) {
      setState(() {
        _expenses = expenses;
        _totalSpending = total;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCamera() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (result == true) {
      _loadExpenses();
    }
  }

  void _openManualAdd() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReceiptReviewScreen(
          receiptImage: null,
          parsedReceipt: ParsedReceipt(
            rawText: '',
            suggestedCategory: ExpenseCategory.food,
            overallConfidence: 1.0,
          ),
        ),
      ),
    );
    if (result == true) {
      _loadExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0 ? _buildTransactionsView() : const AnalyticsScreen(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCamera,
        elevation: 4,
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.document_scanner_rounded),
        label: const Text(
          'Scan OCR',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
          if (idx == 0) _loadExpenses();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsView() {
    // Find top category
    final categoryTotals = <ExpenseCategory, double>{};
    for (final exp in _expenses) {
      categoryTotals[exp.category] = (categoryTotals[exp.category] ?? 0.0) + exp.amount;
    }
    ExpenseCategory? topCat;
    double maxAmt = 0;
    categoryTotals.forEach((cat, amt) {
      if (amt > maxAmt) {
        maxAmt = amt;
        topCat = cat;
      }
    });

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadExpenses,
        child: CustomScrollView(
          slivers: [
            // Top App Bar
            SliverAppBar(
              floating: true,
              pinned: false,
              title: const Text(
                'OCR Expense Tracker',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Add Manual Expense',
                  onPressed: _openManualAdd,
                ),
              ],
            ),

            // Summary Gradient Card
            SliverToBoxAdapter(
              child: SummaryCard(
                totalAmount: _totalSpending,
                transactionCount: _expenses.length,
                topCategory: topCat,
                onScanTap: _openCamera,
              ),
            ),

            // Search Bar & Filters
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => _loadExpenses(),
                      decoration: InputDecoration(
                        hintText: 'Search merchant or notes...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadExpenses();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Horizontal Category Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: _selectedCategoryFilter == null,
                            onSelected: (selected) {
                              setState(() => _selectedCategoryFilter = null);
                              _loadExpenses();
                            },
                          ),
                          const SizedBox(width: 8),
                          ...ExpenseCategory.values.map((cat) {
                            final isSelected = _selectedCategoryFilter == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
                                label: Text(cat.vietnameseName),
                                selected: isSelected,
                                selectedColor: cat.color,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategoryFilter = selected ? cat : null;
                                  });
                                  _loadExpenses();
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expense Items List
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_expenses.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No receipts found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap "Scan OCR" below to capture a receipt.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _expenses[index];
                    return ExpenseListTile(
                      expense: item,
                      onTap: () async {
                        final updated = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ExpenseDetailScreen(expense: item),
                          ),
                        );
                        if (updated == true) _loadExpenses();
                      },
                      onDelete: () async {
                        if (item.id != null) {
                          await DatabaseHelper.instance.deleteExpense(item.id!);
                          _loadExpenses();
                        }
                      },
                    );
                  },
                  childCount: _expenses.length,
                ),
              ),

            // Bottom space for floating action button
            const SliverToBoxAdapter(
              child: SizedBox(height: 90),
            ),
          ],
        ),
      ),
    );
  }
}
