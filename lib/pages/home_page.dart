import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/reminder_item.dart';
import '../models/vehicle.dart';
import '../repositories/user_repository.dart';
import '../repositories/vehicle_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/section_header.dart';
import 'conversion_page.dart';
import 'notifications_page.dart';
import 'service_history_page.dart';

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

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicleRepo.primaryVehicle ??
        (_vehicleRepo.vehicles.isNotEmpty ? _vehicleRepo.vehicles.first : null);
    final user = _userRepo.currentUser;
    final userName = user != null && user.name.isNotEmpty
        ? user.name.split(' ').first
        : 'Pengguna';

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
                        'Halo, $userName 👋',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Selamat datang kembali di DriveMate!',
                        style: TextStyle(
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
            _buildVehicleCard(vehicle),

            const SizedBox(height: 26),

            // AKSES CEPAT (Mockup Layar 3)
            const SectionHeader(title: 'Akses Cepat'),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.build_rounded,
                    label: 'Servis',
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
                    label: 'Lokasi',
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
                    label: 'AI Assistant',
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
                    label: 'Lainnya',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ConversionPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // PENGINGAT (Dinamis dari Database)
            SectionHeader(
              title: 'Pengingat',
              actionLabel: 'Lihat Semua',
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
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppTheme.success,
                      size: 26,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tidak ada pengingat aktif saat ini. Semua jadwal servis & pajak terpantau aman.',
                        style: TextStyle(
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
                        ? 'Jatuh tempo: ${reminder.targetDate}'
                        : (reminder.targetMileage != null
                            ? 'Target: ${_formatMileage(reminder.targetMileage!)} km'
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
            const SectionHeader(title: 'Ringkasan Kendaraan'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.directions_car_outlined,
                    label: 'Total Kendaraan',
                    value: _vehicleRepo.isLoading
                        ? '...'
                        : '${_vehicleRepo.vehicles.length} unit',
                    color: AppTheme.cyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.build_outlined,
                    label: 'Total Servis',
                    value: _isLoadingSummary
                        ? '...'
                        : '$_totalServices kali',
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.notifications_active_outlined,
                    label: 'Pengingat Aktif',
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

  Widget _buildVehicleCard(Vehicle? vehicle) {
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
            const Text(
              'Belum Ada Kendaraan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tambahkan kendaraan untuk mulai memantau servis, jarak tempuh, dan pajak.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
              label: const Text('Tambah Kendaraan'),
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
    final statusStr = vehicle.status.isNotEmpty ? vehicle.status : 'Dalam kondisi baik';

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
                    label: 'Jarak Tempuh',
                    value: mileageStr,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _VehicleStat(
                    icon: Icons.local_gas_station_rounded,
                    label: 'Bahan Bakar',
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
