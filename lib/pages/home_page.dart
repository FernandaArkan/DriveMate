import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _vehicleRepo.addListener(_onDataUpdated);
    _userRepo.addListener(_onDataUpdated);
    _vehicleRepo.loadVehicles();
    _userRepo.initSession();
  }

  @override
  void dispose() {
    _vehicleRepo.removeListener(_onDataUpdated);
    _userRepo.removeListener(_onDataUpdated);
    super.dispose();
  }

  void _onDataUpdated() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicleRepo.primaryVehicle ??
        (_vehicleRepo.vehicles.isNotEmpty ? _vehicleRepo.vehicles.first : null);
    final user = _userRepo.currentUser;
    final userName = user != null ? user.name.split(' ').first : 'Andi';

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
                        'Selamat datang kembali!',
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
                      );
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

            // PENGINGAT (Mockup Layar 3)
            SectionHeader(
              title: 'Pengingat',
              actionLabel: 'Lihat Semua',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _ReminderCard(
              icon: Icons.build_circle_rounded,
              color: const Color(0xFF20B486),
              title: 'Servis Berkala',
              description: 'Dalam 2.500 km lagi',
              detail: '${_formatMileage(vehicle?.mileage ?? 12450)} km / 15.000 km',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceHistoryPage(initialVehicle: vehicle),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _ReminderCard(
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFFFA53D),
              title: 'Pajak Kendaraan',
              description: 'Jatuh tempo ${vehicle?.taxDueDate ?? "12 Jul 2026"}',
              detail: 'Pastikan pajak dibayar tepat waktu',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 26),

            // RINGKASAN KENDARAAN (Mockup Layar 3)
            const SectionHeader(title: 'Ringkasan Kendaraan'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.build_outlined,
                    label: 'Total Servis',
                    value: '4 kali',
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.notifications_active_outlined,
                    label: 'Pengingat Aktif',
                    value: '2',
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
    final title = vehicle != null
        ? '${vehicle.brand} ${vehicle.name} ${vehicle.year}'
        : 'Honda Civic 2022';
    final plate = vehicle?.plate ?? 'B 1234 KZ';
    final mileageStr = '${_formatMileage(vehicle?.mileage ?? 12450)} km';
    final fuelStr = '${vehicle?.fuelLevel ?? 65}%';
    final statusStr = vehicle?.status ?? 'Dalam kondisi baik';

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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFE8EDF5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 13),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
