import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'lending_detail_screen.dart';
import 'add_investment_screen.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_snackbar.dart';

class LendingListScreen extends StatefulWidget {
  const LendingListScreen({super.key});

  @override
  State<LendingListScreen> createState() => _LendingListScreenState();
}

class _LendingListScreenState extends State<LendingListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool isLoading = true;
  List<Map<String, dynamic>> investments = [];

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
      });
    } catch (e) {
      debugPrint('Error loading investments: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Lendings', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: investments.isEmpty 
                  ? const Center(child: Text('No lending added yet.', style: TextStyle(color: Colors.grey))) 
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: investments.length,
                      itemBuilder: (context, index) {
                        final inv = investments[index];
                        final title = inv['title'] ?? 'Unknown Borrower';
                        final principal = double.tryParse(inv['principal_amount']?.toString() ?? '0') ?? 0;
                        final rate = double.tryParse(inv['interest_rate']?.toString() ?? '0') ?? 0;
                        final isActive = inv['status'] == 'Active';
                        final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LendingDetailScreen(investmentId: inv['id'].toString()),
                                ),
                              );
                              _loadData();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                                    child: Icon(LucideIcons.users, color: Colors.orange.shade600, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                                        const SizedBox(height: 4),
                                        Text('${rate.toStringAsFixed(1)}% Interest', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(formatter.format(principal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isActive ? Colors.orange.shade50 : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isActive ? 'Active' : 'Closed',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isActive ? Colors.orange.shade700 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AddInvestmentScreen(initialData: inv),
                                          ),
                                        );
                                        if (result == true) _loadData();
                                      } else if (value == 'delete') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Lending'),
                                            content: const Text('Are you sure you want to delete this lending?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        
                                        if (confirm == true) {
                                          try {
                                            await _supabaseService.deleteInvestment(inv['id'].toString());
                                            _loadData();
                                            if (mounted) {
                                              AppSnackBar.showSuccess(this.context, 'Lending deleted');
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              AppSnackBar.showError(this.context, 'Error deleting lending: ${AppSnackBar.cleanErrorMessage(e)}');
                                            }
                                          }
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
