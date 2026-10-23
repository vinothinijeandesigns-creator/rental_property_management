import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/supabase_service.dart';
import '../utils/app_snackbar.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final String propertyId;
  final String propertyName;

  const PropertyDetailsScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  Map<String, dynamic>? propertyDetails;
  List<Map<String, dynamic>> transactionHistory = [];
  List<Map<String, dynamic>> pendingDues = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPropertyDetails();
  }

  Future<void> _loadPropertyDetails() async {
    setState(() => isLoading = true);
    try {
      final data = await _supabaseService.getPropertyDetails(widget.propertyId);
      
      String? activeAgreementId;
      if (data['agreements'] != null && data['agreements'] is List) {
        List agreements = List.from(data['agreements']);
        agreements.sort((a, b) {
          DateTime dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
          DateTime dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
          if (a['created_at'] == null && a['id'] is int && b['id'] is int) {
             return (b['id'] as int).compareTo(a['id'] as int);
          }
          return dateB.compareTo(dateA);
        });
        data['agreements'] = agreements;
        
        if (agreements.isNotEmpty && data['status'] == 'Occupied') {
          activeAgreementId = agreements[0]['id'].toString();
        }
      }

      final history = await _supabaseService.getPropertyHistory(
        widget.propertyId,
        activeAgreementId: activeAgreementId,
      );
      final dues = await _supabaseService.getPendingDues(
        widget.propertyId,
        activeAgreementId: activeAgreementId,
      );

      setState(() {
        propertyDetails = data;
        transactionHistory = history;
        pendingDues = dues;
      });
    } catch (e) {
      debugPrint('Error loading property details: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.propertyName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (propertyDetails == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.propertyName)),
        body: const Center(child: Text('Property not found.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.propertyName)),
        body: _buildNestedScrollDetails(),
      ),
    );
  }

  Widget _buildNestedScrollDetails() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildPropertyHeaderCard(),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: const [
                  Tab(text: 'Current Tenant'),
                  Tab(text: 'Tenant History'),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        children: [_buildCurrentTenantTab(), _buildTenantHistoryTab()],
      ),
    );
  }

  Widget _buildPropertyHeaderCard() {
    final prop = propertyDetails!;
    final isVacant = prop['status'] == 'Vacant';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isVacant
              ? Colors.orange.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.2),
          width: isVacant ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      prop['property_type'] == 'House'
                          ? LucideIcons.home
                          : LucideIcons.store,
                      color: Theme.of(context).primaryColor,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prop['property_no'] ?? 'Unknown',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prop['property_type'] ?? '-',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isVacant
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    prop['status'] ?? 'Unknown',
                    style: TextStyle(
                      color: isVacant ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(LucideIcons.mapPin, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (prop['buildings']?['address']?.toString().trim().isNotEmpty == true)
                        ? prop['buildings']['address']
                        : (prop['location']?.toString().trim().isNotEmpty == true
                            ? prop['location']
                            : 'Location not provided'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(LucideIcons.zap, size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'EB Meter: ${prop['eb_meter_number']?.toString().isNotEmpty == true ? prop['eb_meter_number'] : 'N/A'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(LucideIcons.droplets, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Water Charge: ${prop['water_charge']?.toString().isNotEmpty == true ? (prop['water_charge'].toString().toLowerCase() == 'included' ? 'Included' : '₹${prop['water_charge']}') : 'N/A'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(LucideIcons.wrench, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Maintenance: ${prop['maintenance_responsibility']?.toString().isNotEmpty == true ? prop['maintenance_responsibility'] : 'N/A'} '
                      '${prop['flat_maintenance_amount'] != null ? '(₹${prop['flat_maintenance_amount']})' : ''}'
                      '${prop['maintenance_frequency'] != null && prop['maintenance_frequency'] != 'N/A' ? ' - ${prop['maintenance_frequency']}' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTenantTab() {
    final prop = propertyDetails!;
    final isVacant = prop['status'] == 'Vacant';

    Map<String, dynamic>? activeAgreement;
    Map<String, dynamic>? tenant;
    bool isRenewEnabled = false;

    if (prop['agreements'] != null && (prop['agreements'] as List).isNotEmpty) {
      activeAgreement = prop['agreements'][0];
      if (activeAgreement?['tenants'] != null) {
        tenant = activeAgreement?['tenants'];
      }
      if (activeAgreement?['end_date'] != null) {
        final endDate = DateTime.tryParse(activeAgreement!['end_date']);
        if (endDate != null) {
          final diff = endDate.difference(DateTime.now()).inDays;
          if (diff <= 30) {
            isRenewEnabled = true;
          }
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isVacant || activeAgreement == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Text(
                      'Property is currently vacant.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showAssignTenantDialog,
                      icon: const Icon(
                        LucideIcons.userPlus,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Assign Tenant',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tenant Details',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (tenant != null)
                  IconButton(
                    icon: const Icon(LucideIcons.edit3, size: 20),
                    color: Colors.blue,
                    onPressed: () => _showEditTenantDialog(tenant!),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow(
                      LucideIcons.user,
                      'Name',
                      tenant?['name'] ?? '-',
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      LucideIcons.phone,
                      'Phone',
                      tenant?['phone'] ?? '-',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Agreement Details',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.edit3, size: 20),
                  color: Colors.blue,
                  onPressed: () => _showEditRentDialog(activeAgreement!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow(
                      LucideIcons.indianRupee,
                      'Monthly Rent',
                      '₹${activeAgreement['monthly_rent'] ?? '-'}',
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      LucideIcons.wallet,
                      'Advance Amount',
                      '₹${activeAgreement['advance_amount'] ?? '-'}',
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      LucideIcons.calendarClock,
                      'Month Rent Start Date',
                      activeAgreement['start_date'] ?? '-',
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      LucideIcons.calendarOff,
                      'Agreement Expiry Date',
                      activeAgreement['end_date'] ?? '-',
                    ),
                    if (prop['flat_maintenance_amount'] != null &&
                        prop['flat_maintenance_amount']
                            .toString()
                            .isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildDetailRow(
                        LucideIcons.wrench,
                        'Maintenance',
                        '₹${prop['flat_maintenance_amount']}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmVacate(activeAgreement!),
                    icon: const Icon(LucideIcons.logOut, color: Colors.red),
                    label: const Text(
                      'Vacate Property',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isRenewEnabled
                        ? () => _showRenewDialog(activeAgreement!)
                        : null,
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Renew',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRenewEnabled
                          ? const Color(0xFF808000)
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      elevation: isRenewEnabled ? 2 : 0,
                      shadowColor: const Color(0xFF808000).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          if (pendingDues.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              'Pending Dues',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingDues.length,
              itemBuilder: (context, index) {
                final due = pendingDues[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      child: Icon(
                        due['type'] == 'eb'
                            ? LucideIcons.zap
                            : LucideIcons.indianRupee,
                        color: Colors.red,
                      ),
                    ),
                    title: Text(
                      due['title'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(due['subtitle']),
                    trailing: Text(
                      '₹${due['amount']}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 32),
          Text(
            'Transaction History',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (transactionHistory.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No transaction history found',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactionHistory.length,
              itemBuilder: (context, index) {
                final tx = transactionHistory[index];
                IconData icon;
                Color color;

                switch (tx['type']) {
                  case 'rent':
                    icon = LucideIcons.indianRupee;
                    color = tx['status'] == 'Paid'
                        ? const Color(0xFF10B981)
                        : Colors.red;
                    break;
                  case 'eb':
                    icon = LucideIcons.zap;
                    color = const Color(0xFFF59E0B);
                    break;
                  case 'maintenance':
                    icon = LucideIcons.wrench;
                    color = const Color(0xFF8B5CF6);
                    break;
                  default:
                    icon = LucideIcons.history;
                    color = Colors.blue;
                }

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.1),
                      child: Icon(icon, color: color),
                    ),
                    title: Text(
                      tx['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(tx['subtitle'] ?? ''),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          tx['amount'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: tx['amount'].toString().startsWith('+')
                                ? Colors.green
                                : (tx['amount'].toString().startsWith('-')
                                      ? Colors.red
                                      : Colors.black87),
                          ),
                        ),
                        if (tx['status'] != null)
                          Text(
                            tx['status'],
                            style: TextStyle(
                              fontSize: 12,
                              color: tx['status'] == 'Paid'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTenantHistoryTab() {
    final prop = propertyDetails!;
    List agreements = prop['agreements'] ?? [];

    List pastAgreements = [];
    if (agreements.isNotEmpty) {
      if (prop['status'] == 'Occupied') {
        pastAgreements = agreements.sublist(1);
      } else {
        pastAgreements = List.from(agreements);
      }
    }

    if (pastAgreements.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No previous tenant history.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pastAgreements.length,
      itemBuilder: (context, index) {
        final agreement = pastAgreements[index];
        final tenant = agreement['tenants'];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          elevation: 0,
          child: ExpansionTile(
            title: Text(
              tenant?['name'] ?? 'Unknown Tenant',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${agreement['start_date'] ?? 'Unknown'} to ${agreement['end_date'] ?? 'Unknown'}',
            ),
            childrenPadding: const EdgeInsets.all(16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tenant?['phone'] != null &&
                  tenant!['phone'].toString().isNotEmpty) ...[
                _buildDetailRow(LucideIcons.phone, 'Phone', tenant['phone']),
                const Divider(height: 24),
              ],
              _buildDetailRow(
                LucideIcons.calendarClock,
                'Agreement Dates',
                '${agreement['start_date'] ?? '-'} to ${agreement['end_date'] ?? '-'}',
              ),
              const Divider(height: 24),
              _buildDetailRow(
                LucideIcons.indianRupee,
                'Monthly Rent',
                '₹${agreement['monthly_rent'] ?? '-'}',
              ),
              const Divider(height: 24),
              _buildDetailRow(
                LucideIcons.wallet,
                'Advance Given',
                '₹${agreement['advance_amount'] ?? '-'}',
              ),
              if (agreement['total_dues_deducted'] != null) ...[
                const Divider(height: 24),
                _buildDetailRow(
                  LucideIcons.receipt,
                  'Dues Deducted',
                  '₹${agreement['total_dues_deducted']}',
                ),
              ],
              if (agreement['settlement_amount'] != null) ...[
                const Divider(height: 24),
                _buildDetailRow(
                  LucideIcons.banknote,
                  'Amount Returned',
                  '₹${agreement['settlement_amount']}',
                ),
              ],
              if (prop['flat_maintenance_amount'] != null &&
                  prop['flat_maintenance_amount'].toString().isNotEmpty) ...[
                const Divider(height: 24),
                _buildDetailRow(
                  LucideIcons.wrench,
                  'Maintenance',
                  '₹${prop['flat_maintenance_amount']}',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditRentDialog(Map<String, dynamic> agreement) async {
    final rentController = TextEditingController(
      text: agreement['monthly_rent']?.toString() ?? '',
    );
    final advanceController = TextEditingController(
      text: agreement['advance_amount']?.toString() ?? '',
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Rent Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rentController,
              decoration: const InputDecoration(
                labelText: 'Monthly Rent (₹)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: advanceController,
              decoration: const InputDecoration(
                labelText: 'Advance Amount (₹)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (rentController.text.isEmpty || advanceController.text.isEmpty) return;

      setState(() => isLoading = true);
      try {
        await _supabaseService.updateAgreementRent(
          agreementId: agreement['id'].toString(),
          newRent: double.parse(rentController.text),
          newAdvance: double.parse(advanceController.text),
        );
        if (mounted) {
          AppSnackBar.showSuccess(context, 'Rent details updated!');
          _loadPropertyDetails();
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
          AppSnackBar.showError(context, 'Error: ${AppSnackBar.cleanErrorMessage(e)}');
        }
      }
    }
  }

  Future<void> _confirmVacate(Map<String, dynamic> agreement) async {
    // Calculate total dues
    double totalDues = 0;
    for (var due in pendingDues) {
      totalDues += double.tryParse(due['amount']?.toString() ?? '0') ?? 0;
    }

    double advanceAmount = double.tryParse(agreement['advance_amount']?.toString() ?? '0') ?? 0;
    double balance = advanceAmount - totalDues;

    if (totalDues > advanceAmount) {
      // Tenant owes more than the advance amount
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pending Dues Found'),
          content: Text(
            'The tenant owes ₹${(totalDues - advanceAmount).toStringAsFixed(2)} more than their advance.\n\n'
            'Advance Amount: ₹$advanceAmount\n'
            'Total Pending Dues: ₹$totalDues\n\n'
            'You cannot vacate this property until the excess dues are cleared or adjusted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Vacate & Settlement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure this tenant is vacating? This will close the current agreement.\n'),
            const Text('Settlement Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Advance Amount: ₹$advanceAmount'),
            Text('Total Dues Deducted: ₹$totalDues', style: const TextStyle(color: Colors.red)),
            const Divider(),
            Text('Amount to Return: ₹$balance', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Confirm Vacate',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isLoading = true);
      try {
        await _supabaseService.vacateProperty(
          agreementId: agreement['id'].toString(),
          propertyId: widget.propertyId,
          totalDuesDeducted: totalDues,
          settlementAmount: balance,
        );
        if (mounted) {
          AppSnackBar.showSuccess(context, 'Property vacated successfully!');
          _loadPropertyDetails(); // Reload data
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
          AppSnackBar.showError(context, 'Error: ${AppSnackBar.cleanErrorMessage(e)}');
        }
      }
    }
  }

  Future<void> _showRenewDialog(Map<String, dynamic> oldAgreement) async {
    final rentController = TextEditingController(
      text: oldAgreement['monthly_rent']?.toString() ?? '',
    );
    final advanceController = TextEditingController(
      text: oldAgreement['advance_amount']?.toString() ?? '',
    );

    DateTime? startDate;
    DateTime? endDate;

    if (oldAgreement['end_date'] != null) {
      final oldEnd = DateTime.tryParse(oldAgreement['end_date']);
      if (oldEnd != null) {
        startDate = oldEnd.add(const Duration(days: 1));
        endDate = DateTime(startDate.year, startDate.month + 11, startDate.day);
      }
    }

    startDate ??= DateTime.now();
    endDate ??= DateTime(startDate.year, startDate.month + 11, startDate.day);

    final startController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(startDate),
    );
    final endController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(endDate),
    );

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Renew Agreement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: rentController,
                  decoration: const InputDecoration(
                    labelText: 'New Monthly Rent (₹)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: advanceController,
                  decoration: const InputDecoration(
                    labelText: 'New Advance Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: startController,
                  decoration: const InputDecoration(
                    labelText: 'Rent Start Date (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate!,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setDialogState(() {
                        startDate = date;
                        startController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(date);
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endController,
                  decoration: const InputDecoration(
                    labelText: 'Agreement End Date (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: endDate!,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setDialogState(() {
                        endDate = date;
                        endController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(date);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (rentController.text.isEmpty ||
                    advanceController.text.isEmpty) {
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Renew'),
            ),
          ],
        ),
      ),
    ).then((confirm) async {
      if (confirm == true) {
        setState(() => isLoading = true);
        try {
          await _supabaseService.renewAgreement(
            oldAgreementId: oldAgreement['id'].toString(),
            propertyId: widget.propertyId,
            tenantId: oldAgreement['tenant_id'].toString(),
            monthlyRent: double.parse(rentController.text),
            advanceAmount: double.parse(advanceController.text),
            startDate: startController.text,
            endDate: endController.text,
          );
          if (mounted) {
            AppSnackBar.showSuccess(context, 'Agreement renewed successfully!');
            _loadPropertyDetails();
          }
        } catch (e) {
          if (mounted) {
            setState(() => isLoading = false);
            AppSnackBar.showError(context, 'Error: ${AppSnackBar.cleanErrorMessage(e)}');
          }
        }
      }
    });
  }

  Future<void> _showEditTenantDialog(Map<String, dynamic> tenant) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: tenant['name']);
    final phoneController = TextEditingController(text: tenant['phone']);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Tenant Details'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tenant Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Tenant Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, true);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isLoading = true);
      try {
        await _supabaseService.updateTenantDetails(
          tenantId: tenant['id'].toString(),
          name: nameController.text.trim(),
          phone: phoneController.text.trim(),
        );
        if (mounted) {
          AppSnackBar.showSuccess(context, 'Tenant details updated successfully!');
          _loadPropertyDetails();
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
          AppSnackBar.showError(context, 'Error: ${AppSnackBar.cleanErrorMessage(e)}');
        }
      }
    }
  }

  Future<void> _showAssignTenantDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final rentController = TextEditingController();
    final advanceController = TextEditingController();

    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime(
      startDate.year,
      startDate.month + 11,
      startDate.day,
    );

    final startController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(startDate),
    );
    final endController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(endDate),
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Tenant'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tenant Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Tenant Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Tenant Phone',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (val) => val == null || val.trim().isEmpty ? 'Phone/Mobile is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: rentController,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Rent (₹)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Monthly Rent is required';
                      if (double.tryParse(val) == null) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: advanceController,
                    decoration: const InputDecoration(
                      labelText: 'Advance Amount (₹)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Advance Amount is required';
                      if (double.tryParse(val) == null) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: startController,
                    decoration: const InputDecoration(
                      labelText: 'Rent Start Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Rent Start Date is required' : null,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setDialogState(() {
                          startDate = date;
                          startController.text = DateFormat(
                            'yyyy-MM-dd',
                          ).format(date);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: endController,
                    decoration: const InputDecoration(
                      labelText: 'Agreement End Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Agreement End Date is required' : null,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setDialogState(() {
                          endDate = date;
                          endController.text = DateFormat(
                            'yyyy-MM-dd',
                          ).format(date);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      setState(() => isLoading = true);
      try {
        await _supabaseService.assignTenantToProperty(
          propertyId: widget.propertyId,
          tenantName: nameController.text,
          tenantPhone: phoneController.text,
          monthlyRent: double.tryParse(rentController.text) ?? 0,
          advanceAmount: double.tryParse(advanceController.text) ?? 0,
          startDate: startController.text,
          endDate: endController.text,
        );
        if (mounted) {
          AppSnackBar.showSuccess(context, 'Tenant assigned successfully!');
          _loadPropertyDetails();
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
          AppSnackBar.showError(context, 'Error: ${AppSnackBar.cleanErrorMessage(e)}');
        }
      }
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
