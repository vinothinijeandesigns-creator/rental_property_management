import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/supabase_service.dart';
import 'add_investment_screen.dart';
import 'lending_detail_screen.dart';
import 'lending_list_screen.dart';
import 'package:intl/intl.dart';

class InvestmentDashboardScreen extends StatefulWidget {
  const InvestmentDashboardScreen({super.key});

  @override
  State<InvestmentDashboardScreen> createState() => _InvestmentDashboardScreenState();
}

class _InvestmentDashboardScreenState extends State<InvestmentDashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool isLoading = true;
  List<Map<String, dynamic>> investments = [];

  // Derived metrics
  double totalInvested = 0;
  double monthlyIncome = 0;
  final List<Map<String, dynamic>> _upcomingReminders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final data = await _supabaseService.getInvestments();
      setState(() {
        investments = data.where((inv) => inv['type'] == 'Lending').toList();
        _calculateMetrics();
      });
    } catch (e) {
      debugPrint('Error loading investments: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _calculateMetrics() {
    totalInvested = 0;
    monthlyIncome = 0;
    _upcomingReminders.clear();
    
    final now = DateTime.now();

    for (var inv in investments) {
      if (inv['status'] == 'Active') {
        final principal = double.tryParse(inv['principal_amount']?.toString() ?? '0') ?? 0;
        final rate = double.tryParse(inv['interest_rate']?.toString() ?? '0') ?? 0;
        totalInvested += principal;
        monthlyIncome += principal * (rate / 100) / 12;
        
        // Calculate pending interest
        final transactions = inv['investment_transactions'] as List? ?? [];
        double totalPrincipalPaid = 0;
        double totalInterestReceived = 0;
        
        for (var p in transactions) {
          if (p['transaction_type'] == 'Principal Repayment') {
             totalPrincipalPaid += double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
          } else if (p['transaction_type'] == 'Interest') {
             totalInterestReceived += double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
          } else if (p['transaction_type'] == 'Settlement') {
             double amount = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
             double settledInterest = amount - principal;
             if (settledInterest > 0) totalInterestReceived += settledInterest;
          }
        }
        
        double remainingPrincipal = principal - totalPrincipalPaid;
        double expectedMonthlyInterest = remainingPrincipal * (rate / 100) / 12;
        
        final startDate = DateTime.tryParse(inv['start_date']?.toString() ?? '') ?? now;
        int monthsPassed = (now.year - startDate.year) * 12 + now.month - startDate.month;
        if (now.day >= startDate.day) {
          monthsPassed++;
        }
        if (monthsPassed < 1) monthsPassed = 1;
        
        double pendingInterest = (monthsPassed * expectedMonthlyInterest) - totalInterestReceived;
        
        if (pendingInterest > 0.5) {
          _upcomingReminders.add({
            'investment': inv,
            'title': inv['title'] ?? 'Unknown',
            'pendingAmount': pendingInterest,
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Investment Dashboard', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Track your investments, grow your future 🌱', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 16.0, bottom: 80.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopSummaryCards(),
                    const SizedBox(height: 24),
                    _buildMyInvestments(),
                    const SizedBox(height: 24),
                    _buildUpcomingReminders(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        backgroundColor: const Color(0xFF808000),
        elevation: 3,
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text('Add Lending', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
  
  void _showAddOptions() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddInvestmentScreen()),
    );
    if (result == true) _loadData();
  }

  Widget _buildTopSummaryCards() {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final activeCount = investments.where((inv) => inv['status'] == 'Active').length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildNewSummaryCard(
              title: 'Total Invested',
              amount: formatter.format(totalInvested),
              subtitle: 'Across $activeCount investment${activeCount == 1 ? '' : 's'}',
              icon: LucideIcons.wallet,
              iconColor: Colors.blue.shade700,
              gradientColors: [Colors.blue.shade50.withValues(alpha: 0.2), Colors.blue.shade100.withValues(alpha: 0.2)],
              bottomRightWidget: Icon(LucideIcons.trendingUp, color: Colors.green.shade500, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildNewSummaryCard(
              title: 'Monthly Income',
              amount: formatter.format(monthlyIncome),
              subtitle: 'From $activeCount source${activeCount == 1 ? '' : 's'}',
              icon: LucideIcons.calendar,
              iconColor: Colors.purple.shade700,
              gradientColors: [Colors.purple.shade50.withValues(alpha: 0.2), Colors.purple.shade100.withValues(alpha: 0.2)],
              bottomRightWidget: Icon(LucideIcons.barChart2, color: Colors.purple.shade400, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewSummaryCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
    required Widget bottomRightWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 16),
              Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(amount, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            ],
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: bottomRightWidget,
          ),
        ],
      ),
    );
  }



  Widget _buildMyInvestments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(LucideIcons.leaf, color: Colors.green.shade600, size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'My Investments',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildInvestmentCategoryCard(
            title: 'Lending (Interest)',
            amount: totalInvested,
            percentage: 100.0, // Since it's the only one for now
            metricTitle: 'Monthly Interest',
            metricValue: monthlyIncome,
            icon: LucideIcons.coins,
            iconColor: Colors.purple.shade700,
            iconBg: Colors.purple.shade50,
            progressColor: Colors.purple.shade500,
            onTap: () {
              final activeLendings = investments.where((inv) => inv['type'] == 'Lending' && inv['status'] == 'Active').toList();
              if (activeLendings.isEmpty && investments.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LendingListScreen())).then((_) => _loadData());
              } else if (activeLendings.length == 1) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => LendingDetailScreen(investmentId: activeLendings[0]['id'].toString()))).then((_) => _loadData());
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LendingListScreen())).then((_) => _loadData());
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInvestmentCategoryCard({
    required String title,
    required double amount,
    required double percentage,
    required String metricTitle,
    required double metricValue,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color progressColor,
    VoidCallback? onTap,
  }) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('Earn interest on your lending', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Active', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invested Amount', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(formatter.format(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('${percentage.toStringAsFixed(1)}% of portfolio', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metricTitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(formatter.format(metricValue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF0F172A))),
                      const SizedBox(height: 16), // to align with left bottom text
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: progressColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.calendar, size: 16, color: Colors.purple.shade400),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Next Interest', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                        const Text('N/A', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text('View Details', style: TextStyle(color: Colors.purple.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14, color: Colors.purple.shade700),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingReminders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(LucideIcons.calendar, color: Colors.blue.shade600, size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Upcoming Reminders',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_upcomingReminders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                children: [
                  Icon(LucideIcons.calendarClock, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No pending interests at the moment.', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("We'll notify you when something is due.", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _upcomingReminders.length,
            itemBuilder: (context, index) {
              final reminder = _upcomingReminders[index];
              final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: Icon(LucideIcons.alertCircle, color: Colors.red.shade600, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reminder['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          Text('Interest Pending', style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(formatter.format(reminder['pendingAmount']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
