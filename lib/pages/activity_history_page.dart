import 'package:flutter/material.dart';

import '../services/activity_service.dart';
import '../theme/app_theme.dart';

class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({super.key});

  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  final ActivityService _activityService = ActivityService.instance;

  List<UserActivity> _allActivities = [];
  bool _isLoading = true;
  String _selectedFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);

    final list = await _activityService.getUserActivities();

    if (mounted) {
      setState(() {
        _allActivities = list;
        _isLoading = false;
      });
    }
  }

  List<UserActivity> get _filteredActivities {
    if (_selectedFilter == 'Semua') return _allActivities;
    if (_selectedFilter == 'Kendaraan') {
      return _allActivities.where((a) => a.category == ActivityCategory.vehicle).toList();
    }
    if (_selectedFilter == 'Servis') {
      return _allActivities.where((a) => a.category == ActivityCategory.service).toList();
    }
    if (_selectedFilter == 'Perjalanan') {
      return _allActivities.where((a) => a.category == ActivityCategory.trip).toList();
    }
    if (_selectedFilter == 'Pengingat') {
      return _allActivities.where((a) => a.category == ActivityCategory.reminder).toList();
    }
    return _allActivities;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Riwayat Aktivitas',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadActivities,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            children: [
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', 'Kendaraan', 'Servis', 'Perjalanan', 'Pengingat'].map((cat) {
                    final isSelected = _selectedFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedFilter = cat),
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

              const SizedBox(height: 16),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_filteredActivities.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 40),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5EDF7)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 14),
                      const Text(
                        'Belum Ada Riwayat Aktivitas',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedFilter == 'Semua'
                            ? 'Aktivitas seperti penambahan kendaraan, servis berkala, dan rute perjalanan akan tercatat secara nyata di sini.'
                            : 'Belum ada aktivitas pada kategori $_selectedFilter.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                ..._filteredActivities.map((act) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6EEF8)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.navy.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: act.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(act.icon, color: act.color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                act.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                act.description,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    act.formattedDate,
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
