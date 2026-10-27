import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../models/user_profile.dart';
import '../repositories/user_repository.dart';
import '../services/biometric_service.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import 'activity_history_page.dart';
import 'feedback_page.dart';
import 'game_page.dart';
import 'settings_page.dart';

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
    LanguageService.instance.addListener(_onUserUpdated);
  }

  @override
  void dispose() {
    _userRepo.removeListener(_onUserUpdated);
    LanguageService.instance.removeListener(_onUserUpdated);
    super.dispose();
  }

  void _onUserUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _editProfileDialog(UserProfile user) async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(l10n.editProfile, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.fullName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(labelText: l10n.registeredEmail),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(labelText: l10n.whatsappNumber),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(l10n.save),
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
          SnackBar(
            content: Text(l10n.profileUpdatedSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDataSheet(UserProfile user) {
    final l10n = AppLocalizations.of(context);
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
            Text(
              l10n.menuUserData,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            _infoRow(l10n.fullName, user.name),
            _infoRow(l10n.registeredEmail, user.email),
            _infoRow(l10n.whatsappNumber, user.phone),
            _infoRow(l10n.accountStatus, l10n.verifiedActive),
            _infoRow(l10n.userIdLabel, 'USR-DM-${user.id.toString().padLeft(4, "0")}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSecurityModal(UserProfile user) {
    final l10n = AppLocalizations.of(context);
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
              Text(
                l10n.menuSecurity,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.biometricLogin, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(l10n.biometricSubtitle, style: const TextStyle(fontSize: 12)),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_reset_rounded, color: AppTheme.primary),
                title: Text(l10n.changePassword, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: Text(l10n.changePasswordSubtitle, style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFaqModal() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.faqTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Text(l10n.faqQ1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(l10n.faqA1, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            Text(l10n.faqQ2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(l10n.faqA2, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _showAboutModal() {
    final l10n = AppLocalizations.of(context);
    showAboutDialog(
      context: context,
      applicationName: 'DriveMate',
      applicationVersion: '1.0.0 (Tugas Akhir)',
      applicationIcon: const Icon(Icons.directions_car_filled_rounded, size: 48, color: AppTheme.primary),
      children: [
        Text(l10n.aboutDescription),
      ],
    );
  }

  void _showLanguageDialog() {
    final l10n = AppLocalizations.of(context);
    final langService = LanguageService.instance;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          l10n.selectLanguage,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.language_rounded, color: AppTheme.primary),
              title: const Text('Bahasa Indonesia'),
              trailing: !langService.isEnglish
                  ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary)
                  : null,
              onTap: () async {
                Navigator.pop(ctx);
                await langService.setLanguage('Bahasa Indonesia');
                if (mounted) setState(() {});
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language_rounded, color: AppTheme.primary),
              title: const Text('English'),
              trailing: langService.isEnglish
                  ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary)
                  : null,
              onTap: () async {
                Navigator.pop(ctx);
                await langService.setLanguage('English');
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(l10n.logoutConfirmTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.logout),
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
    final l10n = AppLocalizations.of(context);
    final user = _userRepo.currentUser ??
        UserProfile(name: 'Andi Pratama', email: 'andi@email.com', phone: '081234567890');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.profileTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _showLanguageDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language_rounded, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          LanguageService.instance.isEnglish ? 'EN' : 'ID',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                    child: Text(l10n.editProfile, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.miniGameTitle,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.miniGameSubtitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
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
                    title: l10n.menuUserData,
                    onTap: () => _showDataSheet(user),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.directions_car_outlined,
                    title: l10n.menuVehicles,
                    onTap: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(1); // Tab Kendaraan
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.settings_outlined,
                    title: l10n.menuSettings,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.lock_outline_rounded,
                    title: l10n.menuSecurity,
                    onTap: () => _showSecurityModal(user),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.history_rounded,
                    title: l10n.menuHistory,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ActivityHistoryPage()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.rate_review_outlined,
                    title: l10n.menuFeedback,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FeedbackPage()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.help_outline_rounded,
                    title: l10n.menuFaq,
                    onTap: _showFaqModal,
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F4FA)),
                  _menuTile(
                    icon: Icons.info_outline_rounded,
                    title: l10n.menuAbout,
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
                label: Text(l10n.logout, style: const TextStyle(fontWeight: FontWeight.w800)),
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
    String? subtitle,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
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
}
