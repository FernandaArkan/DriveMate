import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/activity_service.dart';
import '../services/language_service.dart';
import '../services/timezone_service.dart';
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
  ActivityCategory _selectedFilter = ActivityCategory.all;

  @override
  void initState() {
    super.initState();
    _loadActivities();
    TimeZoneService.instance.addListener(_onSettingsChanged);
    LanguageService.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    TimeZoneService.instance.removeListener(_onSettingsChanged);
    LanguageService.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
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
    if (_selectedFilter == ActivityCategory.all) return _allActivities;
    return _allActivities.where((a) => a.category == _selectedFilter).toList();
  }

  String _filterLabel(ActivityCategory cat, AppLocalizations l10n) {
    switch (cat) {
      case ActivityCategory.all:
        return l10n.filterAll;
      case ActivityCategory.vehicle:
        return l10n.filterVehicles;
      case ActivityCategory.service:
        return l10n.filterServices;
      case ActivityCategory.trip:
        return l10n.filterTrips;
      case ActivityCategory.reminder:
        return l10n.filterReminders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final filterOptions = [
      ActivityCategory.all,
      ActivityCategory.vehicle,
      ActivityCategory.service,
      ActivityCategory.trip,
      ActivityCategory.reminder,
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          l10n.activityHistoryTitle,
          style: const TextStyle(
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
                  children: filterOptions.map((cat) {
                    final isSelected = _selectedFilter == cat;
                    final label = _filterLabel(cat, l10n);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedFilter = cat),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedColor: AppTheme.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFFE2E9F3),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
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
                      Icon(Icons.history_toggle_off_rounded,
                          size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 14),
                      Text(
                        l10n.noActivityTitle,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.noActivityDesc,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
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
                                l10n.translateActivityTitle(act.title),
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
                                  const Icon(Icons.access_time_rounded,
                                      size: 12, color: AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    act.formattedDate,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary),
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
