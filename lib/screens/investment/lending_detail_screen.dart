import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_snackbar.dart';
import 'record_investment_transaction_dialog.dart';

class LendingDetailScreen extends StatefulWidget {
  final String investmentId;
  const LendingDetailScreen({super.key, required this.investmentId});

  @override
  State<LendingDetailScreen> createState() => _LendingDetailScreenState();
}

class _LendingDetailScreenState extends State<LendingDetailScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool isLoading = true;
  Map<String, dynamic>? investment;
  
  double get principal => double.tryParse(investment?['principal_amount']?.toString() ?? '0') ?? 0;
  double get interestRate => double.tryParse(investment?['interest_rate']?.toString() ?? '0') ?? 0;
  double get expectedMonthlyInterest => remainingPrincipal * (interestRate / 100) / 12;
  
  final List<Map<String, dynamic>> _pendingSchedule = [];
  final List<Map<String, dynamic>> _transactions = [];
  double _totalInterestReceived = 0;
  double _pendingInterest = 0;
  double _totalPrincipalPaid = 0;
  double get remainingPrincipal => principal - _totalPrincipalPaid;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      investment = await _supabaseService.getInvestmentDetails(widget.investmentId);
      _calculateTimeline();
    } catch (e) {
      debugPrint('Error loading lending details: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _calculateTimeline() {
    if (investment == null) return;
    
    _pendingSchedule.clear();
    _transactions.clear();
    _totalInterestReceived = 0;
    _totalPrincipalPaid = 0;
    
    final startDate = DateTime.tryParse(investment!['start_date']?.toString() ?? '') ?? DateTime.now();
    final isClosed = investment!['status'] == 'Closed';
    final rawTransactions = investment!['investment_transactions'] as List? ?? [];
    
    // Sort transactions by date descending for History
    rawTransactions.sort((a, b) {
      final dateA = DateTime.tryParse(a['transaction_date']?.toString() ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['transaction_date']?.toString() ?? '') ?? DateTime.now();
      return dateB.compareTo(dateA);
    });
    
    _transactions.addAll(rawTransactions.cast<Map<String, dynamic>>());
    
    Map<String, double> paymentsByMonth = {};
    for (var p in _transactions) {
      if (p['transaction_type'] == 'Settlement') {
         double amount = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
         double settledInterest = amount - principal;
         if (settledInterest > 0) _totalInterestReceived += settledInterest;
      } else if (p['transaction_type'] == 'Interest') {
         double amount = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
         _totalInterestReceived += amount;
         final monthStr = p['related_month']?.toString() ?? '';
         if (monthStr.isNotEmpty) {
            paymentsByMonth[monthStr] = (paymentsByMonth[monthStr] ?? 0) + amount;
         }
      } else if (p['transaction_type'] == 'Principal Repayment') {
         double amount = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
         _totalPrincipalPaid += amount;
      }
    }
    
    final now = DateTime.now();
    final endCalcDate = isClosed ? _getSettlementDate(_transactions) ?? now : now;
    
    int monthsPassed = (endCalcDate.year - startDate.year) * 12 + endCalcDate.month - startDate.month;
    if (endCalcDate.day >= startDate.day || isClosed) {
      monthsPassed++;
    }
    if (monthsPassed < 1) monthsPassed = 1;
    
    _pendingInterest = (monthsPassed * expectedMonthlyInterest) - _totalInterestReceived;
    if (_pendingInterest < 0) _pendingInterest = 0;

    for (int i = 0; i < monthsPassed; i++) {
      DateTime targetMonth = DateTime(startDate.year, startDate.month + i, startDate.day);
      String monthKey = '${targetMonth.month.toString().padLeft(2, '0')}-${targetMonth.year}';
      String displayMonth = DateFormat('MMMM yyyy').format(targetMonth);
      
      double paidForThisMonth = paymentsByMonth[monthKey] ?? 0;
      bool isPaid = paidForThisMonth >= expectedMonthlyInterest - 0.5;

      if (!isPaid) {
        _pendingSchedule.add({
          'monthKey': monthKey,
          'displayMonth': displayMonth,
          'amount': expectedMonthlyInterest - paidForThisMonth,
          'status': targetMonth.isAfter(now) && !isClosed ? 'Upcoming' : 'Pending',
        });
      }
    }
  }
  
  DateTime? _getSettlementDate(List transactions) {
    for (var p in transactions) {
      if (p['transaction_type'] == 'Settlement') {
        return DateTime.tryParse(p['transaction_date']?.toString() ?? '');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Lending Details')), body: const Center(child: CircularProgressIndicator()));
    }
    if (investment == null) {
      return Scaffold(appBar: AppBar(title: const Text('Lending Details')), body: const Center(child: Text('Investment not found')));
    }

    final isClosed = investment!['status'] == 'Closed';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(investment!['title'] ?? 'Lending Details', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(child: Text('Pending / Upcoming', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                if (!isClosed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: _showRecordPrincipalDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF808000),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Pay Principal', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _showSettleDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Settle', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPendingSchedule(),
            const SizedBox(height: 24),
            const Text('Payment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildPaymentHistory(),
          ],
        ),
      ),
    );
  }
  Future<void> _showRecordPrincipalDialog() async {
    final result = await showDialog(
      context: context,
      builder: (_) => RecordInvestmentTransactionDialog(
        investmentId: widget.investmentId,
        transactionType: 'Principal Repayment',
        title: 'Record Principal Repayment',
        monthKey: DateFormat('MM-yyyy').format(DateTime.now()),
        displayMonth: 'Current',
        defaultAmount: 0,
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _showSettleDialog() async {
    final notesController = TextEditingController();
    bool isSaving = false;
    final totalToReceive = principal + _pendingInterest;
    
    final result = await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Settle Loan', style: TextStyle(color: Colors.red)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Are you sure you want to close this loan?'),
                  const SizedBox(height: 12),
                  Text('Principal: ₹${principal.toStringAsFixed(0)}'),
                  Text('Pending Interest: ₹${_pendingInterest.toStringAsFixed(0)}'),
                  const Divider(),
                  Text('Total to Receive: ₹${totalToReceive.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setState(() => isSaving = true);
                    try {
                      // 1. Record Settlement Transaction
                      await _supabaseService.recordInvestmentTransaction({
                        'investment_id': widget.investmentId,
                        'transaction_type': 'Settlement',
                        'amount': totalToReceive,
                        'transaction_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        'notes': notesController.text,
                      });
                      
                      // 2. Mark Closed
                      await _supabaseService.closeInvestment(widget.investmentId);
                      
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) {
                        AppSnackBar.showError(context, AppSnackBar.cleanErrorMessage(e));
                        setState(() => isSaving = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Settle & Close', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
    
    if (result == true) _loadData();
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Remaining Principal', style: TextStyle(color: Colors.grey.shade600)),
                    Text('₹${remainingPrincipal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: investment!['status'] == 'Closed' ? Colors.grey.shade200 : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    investment!['status'] ?? 'Unknown',
                    style: TextStyle(
                      color: investment!['status'] == 'Closed' ? Colors.grey.shade700 : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Original Principal', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text('₹${principal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Principal Paid', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text('₹${_totalPrincipalPaid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Interest Rate', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text('$interestRate%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Monthly Interest', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text('₹${expectedMonthlyInterest.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Received', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text('₹${_totalInterestReceived.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Pending Interest', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text('₹${_pendingInterest.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSchedule() {
    if (_pendingSchedule.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No pending interests', style: TextStyle(color: Colors.grey))));
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pendingSchedule.length,
      itemBuilder: (context, index) {
        final item = _pendingSchedule[index];
        final status = item['status'];
        final isClosed = investment!['status'] == 'Closed';
        
        Color statusColor = status == 'Pending' ? Colors.red : Colors.grey;
        IconData statusIcon = status == 'Pending' ? LucideIcons.alertCircle : LucideIcons.clock;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: Text(item['displayMonth'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('₹${item['amount'].toStringAsFixed(0)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == 'Pending' && !isClosed)
                  TextButton(
                    onPressed: () async {
                      final result = await showDialog(
                        context: context,
                        builder: (_) => RecordInvestmentTransactionDialog(
                          investmentId: widget.investmentId,
                          transactionType: 'Interest',
                          title: 'Record Interest',
                          monthKey: item['monthKey'],
                          displayMonth: item['displayMonth'],
                          defaultAmount: item['amount'],
                        ),
                      );
                      if (result == true) _loadData();
                    },
                    child: const Text('Record Payment'),
                  ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 4),
                    Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentHistory() {
    if (_transactions.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No history yet', style: TextStyle(color: Colors.grey))));
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final type = tx['transaction_type'] ?? 'Unknown';
        final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
        final txDate = DateTime.tryParse(tx['transaction_date']?.toString() ?? '') ?? DateTime.now();
        final relatedMonth = tx['related_month'] ?? ''; // e.g. '09-2026'
        
        String title = type;
        if (type == 'Interest' && relatedMonth.isNotEmpty) {
           try {
             final parts = relatedMonth.split('-');
             if (parts.length == 2) {
               final m = int.parse(parts[0]);
               final y = int.parse(parts[1]);
               final date = DateTime(y, m);
               title = 'Interest (${DateFormat('MMM yyyy').format(date)})';
             }
           } catch (_) {}
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
              child: Icon(
                type == 'Interest' ? LucideIcons.coins : (type == 'Settlement' ? LucideIcons.checkCircle : LucideIcons.banknote),
                color: Colors.blue.shade600,
                size: 20,
              ),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('dd MMM yyyy').format(txDate)),
            trailing: Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        );
      },
    );
  }
}
