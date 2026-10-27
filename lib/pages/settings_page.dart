
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_config.dart';
import '../localization/app_localizations.dart';
import '../services/language_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SyncService _syncService = SyncService.instance;
  final LanguageService _languageService = LanguageService.instance;

  bool _isLoading = true;

  // Notifikasi
  bool _reminderService = true;
  bool _reminderTax = true;
  bool _reminderWeather = true;

  // Preferensi
  String _language = 'Bahasa Indonesia';
  String _distanceUnit = 'Kilometer (km)';

  static const String _keyReminderService = 'setting_reminder_service';
  static const String _keyReminderTax = 'setting_reminder_tax';
  static const String _keyReminderWeather = 'setting_reminder_weather';
  static const String _keyLanguage = 'setting_language';
  static const String _keyDistanceUnit = 'setting_distance_unit';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _syncService.addListener(_onSyncUpdated);
    _languageService.addListener(_onLanguageUpdated);
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncUpdated);
    _languageService.removeListener(_onLanguageUpdated);
    super.dispose();
  }

  void _onSyncUpdated() {
    if (mounted) setState(() {});
  }

  void _onLanguageUpdated() {
    if (mounted) {
      setState(() {
        _language = _languageService.languageName;
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _reminderService = prefs.getBool(_keyReminderService) ?? true;
      _reminderTax = prefs.getBool(_keyReminderTax) ?? true;
      _reminderWeather = prefs.getBool(_keyReminderWeather) ?? true;
      _language = _languageService.languageName;
      _distanceUnit =
          prefs.getString(_keyDistanceUnit) ?? 'Kilometer (km)';
      _isLoading = false;
    });
  }

  Future<void> _updateBool(
    String key,
    bool value,
    void Function() apply,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (!mounted) return;
    setState(apply);
  }

  Future<void> _updateString(
    String key,
    String value,
    void Function() apply,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    if (!mounted) return;
    setState(apply);
  }

  Future<void> _triggerManualSync() async {
    final l10n = AppLocalizations.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.startSyncMessage),
        duration: const Duration(seconds: 1),
      ),
    );

    await _syncService.syncPendingData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_syncService.syncStatusMessage),
        backgroundColor:
            _syncService.isOnline ? AppTheme.success : AppTheme.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    final l10n = AppLocalizations.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          l10n.resetDialogTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(l10n.resetDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.reset),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_keyReminderService);
      await prefs.remove(_keyReminderTax);
      await prefs.remove(_keyReminderWeather);
      await prefs.remove(_keyLanguage);
      await prefs.remove(_keyDistanceUnit);

      await _languageService.setLanguage('Bahasa Indonesia');
      await _loadSettings();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.resetSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  // SECTION 1: NOTIFIKASI & PENGINGAT
                  _buildSectionTitle(l10n.sectionNotifications),
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(
                        color: Color(0xFFE5EDF7),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 2,
                          ),
                          title: Text(
                            l10n.periodicServiceReminder,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            l10n.periodicServiceReminderSub,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          value: _reminderService,
                          activeThumbColor: AppTheme.primary,
                          onChanged: (val) {
                            _updateBool(
                              _keyReminderService,
                              val,
                              () => _reminderService = val,
                            );
                          },
                        ),
                        const Divider(
                          height: 1,
                          indent: 18,
                          endIndent: 18,
                          color: Color(0xFFF0F4FA),
                        ),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 2,
                          ),
                          title: Text(
                            l10n.taxReminder,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            l10n.taxReminderSub,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          value: _reminderTax,
                          activeThumbColor: AppTheme.primary,
                          onChanged: (val) {
                            _updateBool(
                              _keyReminderTax,
                              val,
                              () => _reminderTax = val,
                            );
                          },
                        ),
                        const Divider(
                          height: 1,
                          indent: 18,
                          endIndent: 18,
                          color: Color(0xFFF0F4FA),
                        ),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 2,
                          ),
                          title: Text(
                            l10n.weatherSensorWarning,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            l10n.weatherSensorWarningSub,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          value: _reminderWeather,
                          activeThumbColor: AppTheme.primary,
                          onChanged: (val) {
                            _updateBool(
                              _keyReminderWeather,
                              val,
                              () => _reminderWeather = val,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // SECTION 2: PREFERENSI APLIKASI
                  _buildSectionTitle(l10n.sectionPreferences),
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(
                        color: Color(0xFFE5EDF7),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          leading: const Icon(
                            Icons.language_rounded,
                            color: AppTheme.primary,
                          ),
                          title: Text(
                            l10n.language,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            _language,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          trailing: DropdownButton<String>(
                            value: _language,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                value: 'Bahasa Indonesia',
                                child: Text('Indonesia'),
                              ),
                              DropdownMenuItem(
                                value: 'English',
                                child: Text('English'),
                              ),
                            ],
                            onChanged: (val) async {
                              if (val != null) {
                                await _languageService.setLanguage(val);
                                if (!mounted) return;
                                setState(() => _language = val);
                              }
                            },
                          ),
                        ),
                        const Divider(
                          height: 1,
                          indent: 18,
                          endIndent: 18,
                          color: Color(0xFFF0F4FA),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          leading: const Icon(
                            Icons.straighten_rounded,
                            color: AppTheme.primary,
                          ),
                          title: Text(
                            l10n.distanceUnit,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            _distanceUnit,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          trailing: DropdownButton<String>(
                            value: _distanceUnit,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                value: 'Kilometer (km)',
                                child: Text('km'),
                              ),
                              DropdownMenuItem(
                                value: 'Mil (mi)',
                                child: Text('mi'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                _updateString(
                                  _keyDistanceUnit,
                                  val,
                                  () => _distanceUnit = val,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // SECTION 3: SINKRONISASI SERVER & KONEKSI
                  _buildSectionTitle(l10n.sectionSync),
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(
                        color: Color(0xFFE5EDF7),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _syncService.isOnline
                                    ? Icons.cloud_done_rounded
                                    : Icons.cloud_off_rounded,
                                color: _syncService.isOnline
                                    ? AppTheme.success
                                    : AppTheme.warning,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _syncService.syncStatusMessage,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: _syncService.isOnline
                                        ? AppTheme.success
                                        : AppTheme.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.serverApi,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            ApiConfig.baseUrl,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _syncService.isSyncing
                                  ? null
                                  : _triggerManualSync,
                              icon: _syncService.isSyncing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.sync_rounded,
                                      size: 18,
                                    ),
                              label: Text(
                                _syncService.isSyncing
                                    ? l10n.syncing
                                    : l10n.syncNow,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: const BorderSide(
                                  color: AppTheme.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Reset Button
                  Center(
                    child: TextButton.icon(
                      onPressed: _resetToDefaults,
                      icon: const Icon(
                        Icons.restore_rounded,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      label: Text(
                        l10n.resetSettings,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
