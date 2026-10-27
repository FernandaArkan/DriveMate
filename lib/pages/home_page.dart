import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/reminder_item.dart';
import '../models/vehicle.dart';
import '../repositories/user_repository.dart';
import '../repositories/vehicle_repository.dart';
import '../services/language_service.dart';
import '../services/timezone_service.dart';
import '../theme/app_theme.dart';
import '../widgets/section_header.dart';
import 'activity_history_page.dart';
import 'feedback_page.dart';
import 'game_page.dart';
import 'notifications_page.dart';
import 'service_history_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final VehicleRepository _vehicleRepo = VehicleRepository.instance;
  final UserRepository _userRepo = UserRepository.instance;

  int _totalServices = 0;
  int _activeRemindersCount = 0;
  List<ReminderItem> _activeReminders = [];
  bool _isLoadingSummary = false;

  @override
  void initState() {
    super.initState();
    _vehicleRepo.addListener(_onDataUpdated);
    _userRepo.addListener(_onDataUpdated);
    LanguageService.instance.addListener(_onDataUpdated);
    _initData();
  }

  Future<void> _initData() async {
    await _userRepo.initSession();
    await _vehicleRepo.loadVehicles();
    await _loadSummaryData();
  }

  @override
  void dispose() {
    _vehicleRepo.removeListener(_onDataUpdated);
    _userRepo.removeListener(_onDataUpdated);
    LanguageService.instance.removeListener(_onDataUpdated);
    super.dispose();
  }

  void _onDataUpdated() {
    if (mounted) {
      setState(() {});
      _loadSummaryData();
    }
  }

  Future<void> _loadSummaryData() async {
    if (!mounted) return;
    setState(() => _isLoadingSummary = true);

    try {
      final db = DatabaseHelper.instance;
      final vehicle = _vehicleRepo.primaryVehicle ??
          (_vehicleRepo.vehicles.isNotEmpty ? _vehicleRepo.vehicles.first : null);

      final services = await db.getServiceRecords(vehicleId: vehicle?.id);
      final allReminders = await db.getReminders();
      final active = allReminders.where((r) => !r.isRead).toList();

      if (mounted) {
        setState(() {
          _totalServices = services.length;
          _activeRemindersCount = active.length;
          _activeReminders = active.take(2).toList();
          _isLoadingSummary = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading summary data: $e');
      if (mounted) {
        setState(() => _isLoadingSummary = false);
      }
    }
  }

  void _showMoreMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.apps_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.moreFeatures,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _moreMenuItem(
                icon: Icons.settings_outlined,
                color: AppTheme.primary,
                title: l10n.menuSettings,
                subtitle: l10n.settingsMenuSub,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
              const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
              _moreMenuItem(
                icon: Icons.history_rounded,
                color: const Color(0xFF20B486),
                title: l10n.menuHistory,
                subtitle: l10n.historyMenuSub,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ActivityHistoryPage()),
                  );
                },
              ),
              const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
              _moreMenuItem(
                icon: Icons.sports_esports_outlined,
                color: const Color(0xFF0288D1),
                title: l10n.miniGameTitle,
                subtitle: l10n.miniGameSubtitle,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GamePage()),
                  );
                },
              ),
              const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
              _moreMenuItem(
                icon: Icons.rate_review_outlined,
                color: const Color(0xFFFFA53D),
                title: l10n.menuFeedback,
                subtitle: l10n.feedbackMenuSub,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeedbackPage()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _moreMenuItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehicle = _vehicleRepo.primaryVehicle ??
        (_vehicleRepo.vehicles.isNotEmpty ? _vehicleRepo.vehicles.first : null);
    final user = _userRepo.currentUser;
    final userName = user != null && user.name.isNotEmpty
        ? user.name.split(' ').first
        : (l10n.isEnglish ? 'Driver' : 'Pengguna');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            // HEADER (Mockup Layar 3)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.hello}, $userName 👋',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        l10n.homeWelcomeBack,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    if (widget.onNavigateTab != null) {
                      widget.onNavigateTab!(4); // Tab Profil
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE4EAF4),
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // KARTU KENDARAAN (Mockup Layar 3)
            _buildVehicleCard(vehicle, l10n),

            const SizedBox(height: 26),

            // AKSES CEPAT (Mockup Layar 3)
            SectionHeader(
              title: l10n.isEnglish ? 'Quick Actions' : 'Akses Cepat',
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.build_rounded,
                    label: l10n.quickService,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceHistoryPage(initialVehicle: vehicle),
                        ),
                      ).then((_) => _loadSummaryData());
                    },
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.location_on_rounded,
                    label: l10n.quickLocation,
                    onTap: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(2); // Tab Perjalanan
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.smart_toy_rounded,
                    label: l10n.quickAiAssistant,
                    onTap: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(3); // Tab AI
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.more_horiz_rounded,
                    label: l10n.quickMore,
                    onTap: () => _showMoreMenu(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // PENGINGAT (Dinamis dari Database)
            SectionHeader(
              title: l10n.reminders,
              actionLabel: l10n.viewAll,
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsPage(),
                  ),
                ).then((_) => _loadSummaryData());
              },
            ),

            const SizedBox(height: 12),

            if (_isLoadingSummary)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else if (_activeReminders.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: const Color(0xFFE8EDF5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppTheme.success,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.noRemindersHome,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._activeReminders.map((reminder) {
                IconData remIcon = Icons.notifications_active_rounded;
                Color remColor = AppTheme.primary;
                if (reminder.category.toLowerCase().contains('servis')) {
                  remIcon = Icons.build_circle_rounded;
                  remColor = const Color(0xFF20B486);
                } else if (reminder.category.toLowerCase().contains('pajak')) {
                  remIcon = Icons.receipt_long_rounded;
                  remColor = const Color(0xFFFFA53D);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReminderCard(
                    icon: remIcon,
                    color: remColor,
                    title: reminder.title,
                    description: reminder.message,
                    detail: reminder.targetDate != null
                        ? '${l10n.dueLabel}: ${TimeZoneService.instance.formatFlexibleString(reminder.targetDate!)}'
                        : (reminder.targetMileage != null
                            ? '${l10n.targetLabel}: ${_formatMileage(reminder.targetMileage!)} km'
                            : reminder.timeAgo),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      ).then((_) => _loadSummaryData());
                    },
                  ),
                );
              }),

            const SizedBox(height: 24),

            // RINGKASAN KENDARAAN (Dinamis Aktual)
            SectionHeader(title: l10n.vehicleSummary),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.directions_car_outlined,
                    label: l10n.totalVehicles,
                    value: _vehicleRepo.isLoading
                        ? '...'
                        : '${_vehicleRepo.vehicles.length} ${l10n.unitLabel}',
                    color: AppTheme.cyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.build_outlined,
                    label: l10n.totalServices,
                    value: _isLoadingSummary
                        ? '...'
                        : '$_totalServices ${l10n.timesLabel}',
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.notifications_active_outlined,
                    label: l10n.activeReminders,
                    value: _isLoadingSummary
                        ? '...'
                        : '$_activeRemindersCount',
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Vehicle? vehicle, AppLocalizations l10n) {
    if (vehicle == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF254C7C),
              Color(0xFF102B4A),
              Color(0xFF071D32),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: 0.17),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(
              Icons.directions_car_filled_rounded,
              color: AppTheme.cyan,
              size: 46,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.noVehicleTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.noVehicleDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFBFD7F1),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(1); // Tab Kendaraan
                }
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.addVehicle),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
            ),
          ],
        ),
      );
    }

    final title = '${vehicle.brand} ${vehicle.name} ${vehicle.year}';
    final plate = vehicle.plate;
    final mileageStr = '${_formatMileage(vehicle.mileage)} km';
    final fuelStr = '${vehicle.fuelLevel}%';
    final statusStr = vehicle.status.isNotEmpty ? vehicle.status : l10n.inGoodCondition;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF254C7C),
            Color(0xFF102B4A),
            Color(0xFF071D32),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.17),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      plate,
                      style: const TextStyle(
                        color: Color(0xFFBFD7F1),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.circle,
                      color: Color(0xFF42DEA7),
                      size: 7,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusStr,
                      style: const TextStyle(
                        color: Color(0xFF8CF0C8),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // GAMBAR MOBIL
          SizedBox(
            width: double.infinity,
            height: 125,
            child: Image.asset(
              'assets/images/honda_civic.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
              errorBuilder: (context, error, stackTrace) {
                return const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    size: 95,
                    color: AppTheme.cyan,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // INFORMASI KENDARAAN (Jarak Tempuh & Bahan Bakar)
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 13,
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _VehicleStat(
                    icon: Icons.speed_rounded,
                    label: l10n.mileage,
                    value: mileageStr,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _VehicleStat(
                    icon: Icons.local_gas_station_rounded,
                    label: l10n.fuelLevel,
                    value: fuelStr,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMileage(int mileage) {
    return mileage.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
  }
}

class _VehicleStat extends StatelessWidget {
  const _VehicleStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppTheme.cyan,
          size: 18,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFBFD7F1),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF39A9FF),
                    Color(0xFF0877F9),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.detail,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: const Color(0xFFE8EDF5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    detail,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE8EDF5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
