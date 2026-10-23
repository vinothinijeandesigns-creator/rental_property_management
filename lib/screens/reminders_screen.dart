import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/supabase_service.dart';
import 'reminders/add_reminder_dialog.dart';
import '../utils/app_snackbar.dart';


class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final autoReminders = await _supabaseService.getReminders();
    final financialRemindersRaw = await _supabaseService.getFinancialReminders();
    
    List<Map<String, dynamic>> allReminders = List.from(autoReminders);
    
    final now = DateTime.now();
    
    for (var r in financialRemindersRaw) {
      if (r['is_paid'] == true) continue;
      
      final dueDateRaw = DateTime.tryParse(r['due_date'].toString());
      if (dueDateRaw != null) {
         final dueDate = DateTime(dueDateRaw.year, dueDateRaw.month, dueDateRaw.day);
         final today = DateTime(now.year, now.month, now.day);
         final diff = dueDate.difference(today).inDays;
         String type = 'upcoming';
         String title = r['title'] ?? 'Financial Reminder';
         
         if (diff < 0) {
           type = 'critical';
           title = 'Overdue: $title';
         } else if (diff == 0) {
           type = 'warning';
           title = 'Due Today: $title';
         } else if (diff <= 7) {
           type = 'warning';
           title = 'Due in $diff days: $title';
         }
         
         allReminders.add({
           'id': r['id'], // Storing ID to mark as paid
           'title': title,
           'prop': '${r['category']} - ₹${r['amount'] ?? 0}',
           'type': type,
           'icon_type': 'finance',
         });
      }
    }
    
    _reminders = allReminders;
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? const Center(child: Text('All good! No pending reminders.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reminders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final reminder = _reminders[index];
                    final type = reminder['type'] as String;
                    final iconType = reminder['icon_type'] as String;
                    
                    Color bgColor;
                    Color iconColor;
                    
                    if (type == 'critical') {
                      bgColor = Colors.red.withValues(alpha: 0.1);
                      iconColor = Colors.red;
                    } else if (type == 'warning') {
                      bgColor = Colors.orange.withValues(alpha: 0.1);
                      iconColor = Colors.orange;
                    } else {
                      bgColor = Colors.blue.withValues(alpha: 0.1);
                      iconColor = Colors.blue;
                    }

                    IconData iconData;
                    if (iconType == 'rent') {
                      iconData = LucideIcons.calendar;
                    } else if (iconType == 'eb') {
                      iconData = LucideIcons.zap;
                    } else if (iconType == 'agreement') {
                      iconData = LucideIcons.fileText;
                    } else if (iconType == 'finance') {
                      iconData = LucideIcons.banknote;
                    } else {
                      iconData = LucideIcons.bell;
                    }

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: iconColor.withValues(alpha: 0.2)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(iconData, color: iconColor, size: 24),
                        ),
                        title: Text(
                          reminder['title'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(iconType == 'finance' ? LucideIcons.wallet : LucideIcons.building, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(reminder['prop'] as String, style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        trailing: iconType == 'finance' ? IconButton(
                          icon: const Icon(LucideIcons.checkCircle, color: Colors.green),
                          onPressed: () async {
                            final id = reminder['id'] as String;
                            await _supabaseService.updateFinancialReminder(id, {'is_paid': true});
                            // If frequency is Monthly, we should ideally create the next month's reminder here.
                            // For simplicity, we just mark it paid and reload.
                            _loadData();
                            if (context.mounted) AppSnackBar.showSuccess(context, 'Marked as paid!');
                          },
                        ) : null,
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (context) => const AddReminderDialog(),
          );
          if (result == true) {
            _loadData();
          }
        },
        backgroundColor: const Color(0xFF808000),
        elevation: 3,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
