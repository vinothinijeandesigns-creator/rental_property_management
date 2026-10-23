import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_snackbar.dart';

class RecordInvestmentTransactionDialog extends StatefulWidget {
  final String investmentId;
  final String transactionType; // 'Deposit' or 'Interest'
  final String title;
  final String monthKey;
  final String displayMonth;
  final double defaultAmount;

  const RecordInvestmentTransactionDialog({
    super.key,
    required this.investmentId,
    required this.transactionType,
    required this.title,
    required this.monthKey,
    required this.displayMonth,
    required this.defaultAmount,
  });

  @override
  State<RecordInvestmentTransactionDialog> createState() => _RecordInvestmentTransactionDialogState();
}

class _RecordInvestmentTransactionDialogState extends State<RecordInvestmentTransactionDialog> {
  final SupabaseService _supabaseService = SupabaseService();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _paymentDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.defaultAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _supabaseService.recordInvestmentTransaction({
        'investment_id': widget.investmentId,
        'transaction_type': widget.transactionType,
        'amount': double.parse(_amountController.text),
        'transaction_date': DateFormat('yyyy-MM-dd').format(_paymentDate),
        'related_month': widget.monthKey,
        'notes': _notesController.text,
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, AppSnackBar.cleanErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.title} - ${widget.displayMonth}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount (₹)', icon: Icon(LucideIcons.banknote)),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _paymentDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) setState(() => _paymentDate = date);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Payment Date',
                  icon: Icon(LucideIcons.calendar),
                ),
                child: Text(DateFormat('dd MMM yyyy').format(_paymentDate)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (Optional)', icon: Icon(LucideIcons.fileText)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF808000),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
