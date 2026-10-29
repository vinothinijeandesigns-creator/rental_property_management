import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/supabase_service.dart';
import 'profile_screen.dart';
import 'investment/investment_dashboard_screen.dart';
import 'add_property_screen.dart';
import 'quick_actions/collect_rent_dialog.dart';
import 'quick_actions/record_eb_dialog.dart';
import 'quick_actions/maintenance_dialog.dart';
import '../utils/app_snackbar.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {'total': 0, 'occupied': 0, 'vacant': 0};
  Map<String, dynamic> _financeOverview = {
    'total_expected': 0.0,
    'total_collected': 0.0,
    'collection_rate': 0.0,
    'rent_pending_amount': 0.0,
    'rent_pending_properties': 0,
    'eb_pending_amount': 0.0,
    'eb_pending_properties': 0,
  };
  List<Map<String, dynamic>> _recentActivity = [];
  DateTime _selectedFinanceMonth = DateTime.now();
  String _userName = 'Admin';
  String? _avatarUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final stats = await _supabaseService.getDashboardStats();
      
      final currentMonth = '${_selectedFinanceMonth.year}-${_selectedFinanceMonth.month.toString().padLeft(2, '0')}';
      final financeOverview = await _supabaseService.getFinanceOverview(currentMonth);
      final recentActivity = await _supabaseService.getRecentActivity();
      
      final user = _supabaseService.currentUser;
      final name = user?.userMetadata?['full_name'] as String?;
      final avatar = user?.userMetadata?['avatar_url'] as String?;

      if (mounted) {
        setState(() {
          _stats = stats;
          _financeOverview = financeOverview;
          _recentActivity = recentActivity;
          _userName = name ?? 'Admin';
          _avatarUrl = avatar;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to connect to the server. Please check your internet connection and try again.';
        });
      }
    }
  }

  String _getFinanceMonthLabel(DateTime month) {
    final now = DateTime.now();
    if (month.year == now.year && month.month == now.month) {
      return 'This Month';
    } else if ((month.year == now.year && month.month == now.month - 1) ||
        (now.month == 1 && month.year == now.year - 1 && month.month == 12)) {
      return 'Last Month';
    }
    return DateFormat('MMM yyyy').format(month);
  }

  Future<void> _loadFinanceDataForMonth(DateTime month) async {
    setState(() => _selectedFinanceMonth = month);
    try {
      final monthString = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final financeOverview = await _supabaseService.getFinanceOverview(monthString);
      if (mounted) {
        setState(() => _financeOverview = financeOverview);
      }
    } catch (e) {
      debugPrint('Error loading finance data: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to load finance data: ${AppSnackBar.cleanErrorMessage(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Connection Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF808000),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0xFF808000).withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // Light blue-ish background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSummaryRow(),
              const SizedBox(height: 24),
              _buildFinanceOverview(),
              const SizedBox(height: 24),
              _buildSectionHeader('Quick Actions', 'View All'),
              const SizedBox(height: 16),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildSectionHeader('Recent Activity', 'View All'),
              const SizedBox(height: 16),
              _buildRecentActivity(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: Color(0xFF808000),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good Morning! 👋',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Welcome, $_userName',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Here's what's happening today",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Generate Monthly Rent icon removed
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'profile') {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              _loadData(); // Refresh avatar and name after returning
            } else if (value == 'logout') {
              final navigator = Navigator.of(context);
              final auth = context.read<AuthProvider>();
              try {
                await auth.signOut();
              } catch (_) {
                await _supabaseService.signOut();
              }
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20, color: Color(0xFF808000)),
                  SizedBox(width: 8),
                  Text('Profile Settings'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          child: Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                child: _avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: _buildInfoCard(
              title: 'Total Properties',
              value: _stats['total'].toString(),
              subtitle: 'All Properties',
              icon: Icons.domain,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9333EA), Color(0xFF6366F1)], // Purple to Indigo
              ),
              iconColor: const Color(0xFF7C3AED), // Deep purple for icon
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: _buildInfoCard(
              title: 'Occupied',
              value: _stats['occupied'].toString(),
              subtitle: '${_stats['total'] > 0 ? ((_stats['occupied'] / _stats['total']) * 100).round() : 0}% Occupied',
              icon: Icons.verified,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF34D399), Color(0xFF10B981)], // Green
              ),
              iconColor: const Color(0xFF10B981), // Green for icon
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: _buildInfoCard(
              title: 'Vacant',
              value: _stats['vacant'].toString(),
              subtitle: '${_stats['total'] > 0 ? ((_stats['vacant'] / _stats['total']) * 100).round() : 0}% Vacant',
              icon: Icons.home_work_outlined,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)], // Orange
              ),
              iconColor: const Color(0xFFF59E0B), // Orange for icon
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceOverview() {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)], // Blue gradient
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: () {
                        final newMonth = DateTime(_selectedFinanceMonth.year, _selectedFinanceMonth.month - 1, 1);
                        _loadFinanceDataForMonth(newMonth);
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Finance Overview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getFinanceMonthLabel(_selectedFinanceMonth),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                      onPressed: () {
                        final newMonth = DateTime(_selectedFinanceMonth.year, _selectedFinanceMonth.month + 1, 1);
                        _loadFinanceDataForMonth(newMonth);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildFinanceAmount(
                        title: 'Total Expected',
                        amount: currencyFormat.format(_financeOverview['total_expected'] ?? 0),
                        icon: Icons.account_balance_wallet,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _buildFinanceAmount(
                          title: 'Total Collected',
                          amount: currencyFormat.format(_financeOverview['total_collected'] ?? 0),
                          icon: Icons.savings,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Progress Bar
                Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ((_financeOverview['collection_rate'] ?? 0) / 100).clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF34D399), Color(0xFF10B981)], // Bright Green
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Collection Rate',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${(_financeOverview['collection_rate'] ?? 0).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // White overlapping card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildPendingItem(
                    title: 'Rent Pending',
                    amount: currencyFormat.format(_financeOverview['rent_pending_amount'] ?? 0),
                    subtitle: '${_financeOverview['rent_pending_properties'] ?? 0} Properties',
                    icon: Icons.error_outline,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _buildPendingItem(
                      title: 'EB Pending',
                      amount: currencyFormat.format(_financeOverview['eb_pending_amount'] ?? 0),
                      subtitle: '${_financeOverview['eb_pending_properties'] ?? 0} Properties',
                      icon: Icons.bolt,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceAmount({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingItem({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: const TextStyle(
              color: Color(0xFF808000),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildActionItem(
                'Collect Rent',
                Icons.currency_rupee,
                const Color(0xFF3B82F6), // Blue
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CollectRentDialog(selectedMonth: _selectedFinanceMonth)),
                  );
                  if (result == true) _loadData();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionItem(
                'Add Property',
                Icons.add_home,
                const Color(0xFF10B981), // Green
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
                  );
                  if (result == true) _loadData();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionItem(
                'Record EB', 
                Icons.bolt, 
                const Color(0xFFF59E0B), // Orange/Yellow
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RecordEBDialog(selectedMonth: _selectedFinanceMonth)),
                  );
                  if (result == true) _loadData();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildActionItem(
                'Maintenance', 
                Icons.build, 
                const Color(0xFF8B5CF6), // Purple
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MaintenanceDialog()),
                  );
                  if (result == true) _loadData();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionItem(
                'Investment', 
                LucideIcons.trendingUp, 
                const Color(0xFFD97706), // Brown/Orange
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InvestmentDashboardScreen()),
                  );
                  if (result == true) _loadData();
                },
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.2),
                      color,
                      color.withValues(alpha: 0.2),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 36),
                ),
              ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
    );
  }

  Widget _buildRecentActivity() {
    if (_recentActivity.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No recent activity',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      children: _recentActivity.map((activity) {
        IconData icon;
        Color color;
        bool isPositive = activity['amount'].toString().startsWith('+');

        switch (activity['type']) {
          case 'rent':
            icon = Icons.check;
            color = const Color(0xFF10B981);
            break;
          case 'eb':
            icon = Icons.bolt;
            color = const Color(0xFFF59E0B);
            break;
          case 'maintenance':
            icon = Icons.build;
            color = const Color(0xFF8B5CF6);
            break;
          default:
            icon = Icons.info;
            color = Colors.blue;
        }

        String amountStr = activity['amount'].toString();
        if (amountStr.startsWith('+') || amountStr.startsWith('-')) {
          amountStr = '${amountStr[0]}₹${amountStr.substring(1)}';
        } else {
          amountStr = '₹$amountStr';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildActivityTile(
            title: activity['title'] ?? '',
            subtitle: activity['subtitle'] ?? '',
            amount: amountStr,
            time: activity['date'] ?? '',
            icon: icon,
            color: color,
            isPositive: isPositive,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivityTile({
    required String title,
    required String subtitle,
    required String amount,
    required String time,
    required IconData icon,
    required Color color,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPositive ? const Color(0xFF10B981) : color,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    time,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
