import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_snackbar.dart';

class CollectRentDialog extends StatefulWidget {
  final DateTime selectedMonth;
  const CollectRentDialog({super.key, required this.selectedMonth});

  @override
  State<CollectRentDialog> createState() => _CollectRentDialogState();
}

class _CollectRentDialogState extends State<CollectRentDialog> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _didCollectAny = false;

  List<Map<String, dynamic>> _currentMonthRents = [];
  List<Map<String, dynamic>> _previousMonthRents = [];
  
  final _amountController = TextEditingController();
  String _paymentMethod = 'Cash';
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.selectedMonth;
    _loadPendingRents();
  }

  Future<void> _loadPendingRents() async {
    setState(() => _isLoading = true);
    try {
      final currentMonthStr = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
      
      
      // Automatically generate monthly rents before fetching
      try {
        await _supabaseService.generateMonthlyRent();
      } catch (e) {
        debugPrint('RPC generate_monthly_rent_payments failed, using local fallback: $e');
        await _supabaseService.fixMissingRentsForUser();
      }
      
      final currentRents = await _supabaseService.getPendingRentsForCurrentMonth(currentMonthStr);
      final prevRents = await _supabaseService.getAllPastPendingRents(currentMonthStr);
      
      // Filter out duplicates for current month just in case
      final uniqueCurrentRents = <String, Map<String, dynamic>>{};
      for (var rent in currentRents) {
        final propId = rent['agreements']?['properties']?['id']?.toString();
        if (propId != null && !uniqueCurrentRents.containsKey(propId)) {
          uniqueCurrentRents[propId] = rent;
        }
      }

      if (mounted) {
        setState(() {
          _currentMonthRents = uniqueCurrentRents.values.toList();
          _previousMonthRents = prevRents; // Display all past pending rents
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending rents: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitPayment(Map<String, dynamic> rent, String amountStr, String method) async {
    double? amountPaid = double.tryParse(amountStr);
    if (amountPaid == null || amountPaid <= 0) {
      AppSnackBar.showError(context, 'Please enter a valid amount');
      return;
    }

    try {
      final paymentId = rent['id'].toString();
      await _supabaseService.markRentAsPaid(paymentId, amountPaid, method);
      
      _didCollectAny = true;

      // Generate receipt
      final propertyNo = rent['agreements']['properties']['property_no'];
      final tenantName = rent['agreements']['tenants']['name'];
      final month = rent['payment_month'];
      
      final receiptText = '''
🏠 Rental Receipt
Property: $propertyNo
Tenant: $tenantName
Month: $month
Amount Paid: ₹$amountPaid
Payment Method: $method
Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}

Thank you!
''';

      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        Navigator.pop(context); // Close bottom sheet
        _loadPendingRents(); // Refresh list

        // Show share option
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFF2E7D32),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Rent collected successfully!',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    scaffoldMessenger.hideCurrentSnackBar();
                    // ignore: deprecated_member_use
                    Share.share(receiptText);
                  },
                  child: const Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => scaffoldMessenger.hideCurrentSnackBar(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error collecting rent: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Failed to collect rent: ${AppSnackBar.cleanErrorMessage(e)}',
        );
      }
    }
  }

  void _showPaymentSheet(Map<String, dynamic> rent) {
    _amountController.text = rent['pending_amount'].toString();
    _paymentMethod = 'Cash';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Collect Rent', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tenant: ${rent['agreements']['tenants']['name']}'),
                        Text('Month: ${rent['payment_month']}'),
                        Text('Pending: ₹${rent['pending_amount']}', 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount Paid (₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payment),
                    ),
                    items: ['Cash', 'UPI', 'Bank Transfer']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setStateBottomSheet(() => _paymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : () async {
                      setStateBottomSheet(() => _isSubmitting = true);
                      await _submitPayment(rent, _amountController.text, _paymentMethod);
                      if (mounted) {
                        setStateBottomSheet(() => _isSubmitting = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF808000),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: const Color(0xFF808000).withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('Mark as Paid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildRentCard(Map<String, dynamic> rent) {
    final tenantName = rent['agreements']['tenants']['name'];
    final propNo = rent['agreements']['properties']['property_no'];
    final buildingName = rent['agreements']['properties']['buildings']?['name'];
    final propDisplay = buildingName != null ? '$buildingName - $propNo' : propNo;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Property: $propDisplay', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Tenant: $tenantName'),
          Text('Month: ${rent['payment_month']}'),
          Text('Pending: ₹${rent['pending_amount']}', 
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showPaymentSheet(rent),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF808000),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF808000).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Pay'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> rents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        if (rents.isEmpty)
          const Center(child: Text('No pending rents for this period.', style: TextStyle(color: Colors.grey)))
        else
          ...rents.map((rent) => _buildRentCard(rent)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _didCollectAny);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          title: const Text('Collect Rent', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _didCollectAny),
          ),
        ),
        body: SafeArea(
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSection('Current Month Rent', _currentMonthRents),
                      const SizedBox(height: 32),
                      _buildSection('Past Pending Rents', _previousMonthRents),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
