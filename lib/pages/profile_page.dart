import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../repositories/user_repository.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import 'game_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserRepository _userRepo = UserRepository.instance;

  @override
  void initState() {
    super.initState();
    _userRepo.addListener(_onUserUpdated);
  }

  @override
  void dispose() {
    _userRepo.removeListener(_onUserUpdated);
    super.dispose();
  }

  void _onUserUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _editProfileDialog(UserProfile user) async {
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Edit Profil', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Lengkap'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Nomor HP'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final updated = user.copyWith(
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
      );
      await _userRepo.updateProfile(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDataSheet(UserProfile user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Pengguna',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            _infoRow('Nama Lengkap', user.name),
            _infoRow('Email Terdaftar', user.email),
            _infoRow('Nomor WhatsApp', user.phone),
            _infoRow('Status Akun', 'Terverifikasi (Aktif)'),
            _infoRow('ID Pengguna', 'USR-DM-${user.id.toString().padLeft(4, "0")}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSecurityModal(UserProfile user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Keamanan & Biometrik',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Login dengan Sidik Jari / Wajah', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Buka aplikasi lebih cepat dan aman', style: TextStyle(fontSize: 12)),
                value: user.isBiometricEnabled,
                activeThumbColor: AppTheme.primary,
                onChanged: (val) async {
                  if (val) {
                    final auth = await BiometricService.instance.authenticate();
                    if (!auth) return;
                  }
                  await _userRepo.toggleBiometric(val);
                  setModalState(() {});
                },
              ),
              const Divider(color: Color(0xFFF0F4FA)),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lock_reset_rounded, color: AppTheme.primary),
                title: Text('Ubah Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: Text('Perbarui kata sandi akun Anda secara berkala', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFaqModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Bantuan & FAQ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 14),
            Text('Q: Bagaimana cara menambah kendaraan?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('A: Buka tab Kendaraan, lalu tekan tombol "+ Tambah Kendaraan" di bagian atas.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            SizedBox(height: 10),
            Text('Q: Apakah riwayat servis aman?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('A: Ya, setiap buku servis digital dienkripsi dengan algoritma hashing SHA-256 yang memverifikasi integritas data.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _showAboutModal() {
    showAboutDialog(
      context: context,
      applicationName: 'DriveMate',
      applicationVersion: '1.0.0 (Tugas Akhir)',
      applicationIcon: const Icon(Icons.directions_car_filled_rounded, size: 48, color: AppTheme.primary),
      children: const [
        Text(
          'DriveMate — Personal Vehicle Assistant adalah aplikasi asisten pintar otomotif untuk mencatat perawatan, memantau rute dan sensor, asisten AI, serta demonstrasi blockchain servis digital.',
        ),
      ],
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Konfirmasi Logout', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun DriveMate Anda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _userRepo.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _userRepo.currentUser ??
        UserProfile(name: 'Andi Pratama', email: 'andi@email.com', phone: '081234567890');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Text(
              'Profil',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Header Profile Card (Mockup Layar 11)
            Center(
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    ),
                    onPressed: () => _editProfileDialog(user),
                    child: const Text('Edit Profil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Mini Game 2D Banner (Mockup Layar 10)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GamePage()),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.cyan.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Main Mini-Game 2D',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Vehicle Runner • Hindari rintangan di jalan',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Menu List Vertikal (Mockup Layar 11)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5EDF7)),
              ),
              child: Column(
                children: [
                  _menuTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Data Pengguna',
                    onTap: () => _showDataSheet(user),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.directions_car_outlined,
                    title: 'Data Kendaraan',
                    onTap: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(1); // Tab Kendaraan
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.settings_outlined,
                    title: 'Pengaturan',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tema: Light (Default) • Bahasa: Indonesia'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Keamanan & Biometrik',
                    onTap: () => _showSecurityModal(user),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.history_rounded,
                    title: 'Riwayat Aktivitas',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sesi login aktif. Penyimpanan database lokal terhubung.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Bantuan & FAQ',
                    onTap: _showFaqModal,
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Tentang Aplikasi',
                    onTap: _showAboutModal,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: const BorderSide(color: AppTheme.danger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textPrimary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
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
}
