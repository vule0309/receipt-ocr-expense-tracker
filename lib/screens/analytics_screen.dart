import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/database_helper.dart';
import '../utils/currency_formatter.dart';
import '../widgets/animated_donut_chart.dart';
import '../widgets/animated_bar_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  double _totalSpending = 0.0;
  Map<ExpenseCategory, double> _categoryData = {};
  Map<int, double> _weeklyData = {};
  int _selectedPeriod = 0; // 0: All time, 1: This Month, 2: This Week

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    DateTime? startDate;
    final now = DateTime.now();

    if (_selectedPeriod == 1) {
      // This Month
      startDate = DateTime(now.year, now.month, 1);
    } else if (_selectedPeriod == 2) {
      // This Week
      startDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
    }

    final total = await DatabaseHelper.instance.getTotalSpending(startDate: startDate);
    final catMap = await DatabaseHelper.instance.getSpendingByCategory(startDate: startDate);
    final weekMap = await DatabaseHelper.instance.getWeeklySpending(anchorDate: now);

    if (mounted) {
      setState(() {
        _totalSpending = total;
        _categoryData = catMap;
        _weeklyData = weekMap;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Find highest category
    ExpenseCategory? topCat;
    double maxCatSpend = 0.0;
    for (final entry in _categoryData.entries) {
      if (entry.value > maxCatSpend) {
        maxCatSpend = entry.value;
        topCat = entry.key;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Analytics'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Period Selector Segmented Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('All Time')),
                    ButtonSegment(value: 1, label: Text('This Month')),
                    ButtonSegment(value: 2, label: Text('This Week')),
                  ],
                  selected: {_selectedPeriod},
                  onSelectionChanged: (newSelection) {
                    setState(() => _selectedPeriod = newSelection.first);
                    _loadAnalytics();
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 1. Category Distribution CustomPainter Donut Chart Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Category Distribution',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Tap slices for percentage breakdown',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'CustomPainter',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AnimatedDonutChart(
                        data: _categoryData,
                        totalAmount: _totalSpending,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Weekly Spending CustomPainter Bar Chart Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly Spending Trend',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Daily expense distribution with average line',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Interactive',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AnimatedBarChart(weeklyData: _weeklyData),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Category Breakdown Details
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Category Breakdown',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      ...ExpenseCategory.values.map((cat) {
                        final amount = _categoryData[cat] ?? 0.0;
                        final percent = _totalSpending > 0 ? (amount / _totalSpending) : 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(cat.icon, color: cat.color, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    cat.displayName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const Spacer(),
                                  Text(
                                    CurrencyFormatter.formatVND(amount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${(percent * 100).toStringAsFixed(1)}%)',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  backgroundColor: Colors.grey.shade100,
                                  valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
