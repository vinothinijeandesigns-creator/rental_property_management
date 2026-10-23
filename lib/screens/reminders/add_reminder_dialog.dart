import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_snackbar.dart';

class AddReminderDialog extends StatefulWidget {
  const AddReminderDialog({super.key});

  @override
  State<AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<AddReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'Lending';
  DateTime _dueDate = DateTime.now();
  String _frequency = 'Monthly';

  final _supabase = SupabaseService();
  bool _isLoading = false;

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.addFinancialReminder({
        'title': _titleController.text,
        'category': _category,
        'amount': double.tryParse(_amountController.text) ?? 0,
        'due_date': DateFormat('yyyy-MM-dd').format(_dueDate),
        'is_paid': false,
        'frequency': _frequency,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, AppSnackBar.cleanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Reminder'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title (e.g. IOB RD)'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['Lending', 'Rent', 'EB', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime.now(), lastDate: DateTime(2100));
                  if (d != null) setState(() => _dueDate = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Due Date'),
                  child: Text(DateFormat('dd MMM yyyy').format(_dueDate)),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: ['One-time', 'Monthly', 'Yearly'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _frequency = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _isLoading ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
