import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/reminder_item.dart';
import '../theme/app_theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<ReminderItem> _reminders = [];
  bool _isLoading = true;
  String _selectedFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    final list = await _dbHelper.getReminders();
    if (mounted) {
      setState(() {
        _reminders = list;
        _isLoading = false;
      });
    }
  }

  List<ReminderItem> get _filteredList {
    if (_selectedFilter == 'Semua') return _reminders;
    return _reminders.where((r) => r.category.toLowerCase() == _selectedFilter.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Filter Tabs (Semua, Servis, Pajak, Sistem)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Semua', 'Servis', 'Pajak', 'Sistem'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() => _selectedFilter = filter);
                      },
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      selectedColor: AppTheme.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : const Color(0xFFE2E9F3),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 18),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_filteredList.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Tidak ada notifikasi dalam kategori ini.'),
                ),
              )
            else
              ..._filteredList.map((item) => _buildNotificationCard(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(ReminderItem item) {
    Color iconColor;
    Color iconBg;
    IconData iconData;

    switch (item.category.toLowerCase()) {
      case 'servis':
        iconColor = AppTheme.danger;
        iconBg = AppTheme.danger.withValues(alpha: 0.12);
        iconData = Icons.warning_rounded;
        break;
      case 'pajak':
        iconColor = AppTheme.warning;
        iconBg = AppTheme.warning.withValues(alpha: 0.14);
        iconData = Icons.receipt_long_rounded;
        break;
      default:
        if (item.title.toLowerCase().contains('cuaca')) {
          iconColor = AppTheme.cyan;
          iconBg = AppTheme.cyan.withValues(alpha: 0.14);
          iconData = Icons.cloud_outlined;
        } else {
          iconColor = AppTheme.success;
          iconBg = AppTheme.success.withValues(alpha: 0.14);
          iconData = Icons.system_update_rounded;
        }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      item.timeAgo,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
