
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_config.dart';
import '../localization/app_localizations.dart';
import '../services/currency_service.dart';
import '../services/language_service.dart';
import '../services/security_service.dart';
import '../services/sync_service.dart';
import '../services/timezone_service.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SyncService _syncService = SyncService.instance;
  final LanguageService _languageService = LanguageService.instance;
  final CurrencyService _currencyService = CurrencyService.instance;
  final TimeZoneService _timezoneService = TimeZoneService.instance;
  final SecurityService _securityService = SecurityService.instance;

  bool _isLoading = true;

  // Notifikasi
  bool _reminderService = true;
  bool _reminderTax = true;
  bool _reminderWeather = true;

  // Preferensi
  String _language = 'Bahasa Indonesia';
  String _currency = 'IDR';
  String _timezone = 'Asia/Jakarta';
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
    _currencyService.addListener(_onCurrencyUpdated);
    _timezoneService.addListener(_onTimeZoneUpdated);
    _securityService.addListener(_onSecurityUpdated);
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncUpdated);
    _languageService.removeListener(_onLanguageUpdated);
    _currencyService.removeListener(_onCurrencyUpdated);
    _timezoneService.removeListener(_onTimeZoneUpdated);
    _securityService.removeListener(_onSecurityUpdated);
    super.dispose();
  }

  void _onSecurityUpdated() {
    if (mounted) setState(() {});
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

  void _onCurrencyUpdated() {
    if (mounted) {
      setState(() {
        _currency = _currencyService.currentCurrencyCode;
      });
    }
  }

  void _onTimeZoneUpdated() {
    if (mounted) {
      setState(() {
        _timezone = _timezoneService.currentTimeZoneId;
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
      _currency = _currencyService.currentCurrencyCode;
      _timezone = _timezoneService.currentTimeZoneId;
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
      await prefs.remove(CurrencyService.keyCurrency);
      await prefs.remove(TimeZoneService.keyTimeZone);
      await prefs.remove(_keyDistanceUnit);

      await _languageService.setLanguage('Bahasa Indonesia');
      await _currencyService.setCurrency('IDR');
      await _timezoneService.setTimeZone('Asia/Jakarta');
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

  Future<void> _showSetPinDialog() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                l10n.createPinDialogTitle,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: l10n.enterPinToUnlock,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: l10n.confirmPinDialogTitle,
                      counterText: '',
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final confirm = confirmController.text.trim();
                    if (pin.length < 6) {
                      setDialogState(() {
                        errorText = l10n.pinMustBe6Digits;
                      });
                      return;
                    }
                    if (pin != confirm) {
                      setDialogState(() {
                        errorText = l10n.pinMismatch;
                      });
                      return;
                    }
                    final ok = await _securityService.setPin(pin);
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    if (ok && mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.pinCreatedSuccess),
                          backgroundColor: AppTheme.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showChangePinDialog() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmNewController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                l10n.pinChangeButton,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: l10n.enterCurrentPinTitle,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: l10n.enterNewPinTitle,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmNewController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: l10n.confirmPinDialogTitle,
                      counterText: '',
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () async {
                    final oldPin = oldPinController.text.trim();
                    final newPin = newPinController.text.trim();
                    final confirm = confirmNewController.text.trim();
                    if (newPin.length < 6) {
                      setDialogState(() {
                        errorText = l10n.pinMustBe6Digits;
                      });
                      return;
                    }
                    if (newPin != confirm) {
                      setDialogState(() {
                        errorText = l10n.pinMismatch;
                      });
                      return;
                    }
                    final ok = await _securityService.changePin(
                      oldPin: oldPin,
                      newPin: newPin,
                    );
                    if (!ok) {
                      setDialogState(() {
                        errorText = l10n.pinIncorrect;
                      });
                      return;
                    }
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.pinChangedSuccess),
                          backgroundColor: AppTheme.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDisablePinDialog() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final pinController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                l10n.pinDisableButton,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: l10n.enterCurrentPinTitle,
                      counterText: '',
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final ok = await _securityService.disablePin(pin);
                    if (!ok) {
                      setDialogState(() {
                        errorText = l10n.pinIncorrect;
                      });
                      return;
                    }
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.pinDisabledSuccess),
                          backgroundColor: AppTheme.warning,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Text(l10n.pinDisableButton),
                ),
              ],
            );
          },
        );
      },
    );
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
                        // Bahasa
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
                        // Mata Uang
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          leading: const Icon(
                            Icons.payments_rounded,
                            color: AppTheme.primary,
                          ),
                          title: Text(
                            l10n.currency,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            _currencyService.currentCurrency.label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          trailing: DropdownButton<String>(
                            value: _currency,
                            underline: const SizedBox.shrink(),
                            items: CurrencyService.supportedCurrencies.values
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.code,
                                    child: Text('${c.code} (${c.symbol})'),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) async {
                              if (val != null) {
                                await _currencyService.setCurrency(val);
                                if (!mounted) return;
                                setState(() => _currency = val);
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
                        // Zona Waktu
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          leading: const Icon(
                            Icons.schedule_rounded,
                            color: AppTheme.primary,
                          ),
                          title: Text(
                            l10n.timeZone,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            _timezoneService.currentLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          trailing: DropdownButton<String>(
                            value: _timezone,
                            underline: const SizedBox.shrink(),
                            items: TimeZoneService.supportedTimeZones.values
                                .map(
                                  (tz) => DropdownMenuItem(
                                    value: tz.id,
                                    child: Text(tz.abbreviation),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) async {
                              if (val != null) {
                                await _timezoneService.setTimeZone(val);
                                if (!mounted) return;
                                setState(() => _timezone = val);
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
                        // Satuan Jarak
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

                  // SECTION 3: KEAMANAN & AUTENTIKASI
                  _buildSectionTitle(l10n.sectionSecurity),
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
                        // Biometrik
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 2,
                          ),
                          secondary: const Icon(
                            Icons.fingerprint_rounded,
                            color: AppTheme.primary,
                          ),
                          title: Text(
                            l10n.biometricLockTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            l10n.biometricLockSub,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          value: _securityService.isBiometricEnabled,
                          activeThumbColor: AppTheme.primary,
                          onChanged: (val) async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (val) {
                              final available = await _securityService.isBiometricHardwareAvailable();
                              final enrolled = await _securityService.isBiometricEnrolled();
                              if (!available || !enrolled) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.biometricNotEnrolledMsg),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppTheme.warning,
                                  ),
                                );
                                return;
                              }
                              final success = await _securityService.setBiometricEnabled(true);
                              if (!success && mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.biometricAuthFailedMsg),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppTheme.danger,
                                  ),
                                );
                              }
                            } else {
                              await _securityService.setBiometricEnabled(false);
                            }
                          },
                        ),
                        const Divider(
                          height: 1,
                          indent: 18,
                          endIndent: 18,
                          color: Color(0xFFF0F4FA),
                        ),
                        // PIN Section
                        if (!_securityService.isPinSet)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 4,
                            ),
                            leading: const Icon(
                              Icons.pin_rounded,
                              color: AppTheme.primary,
                            ),
                            title: Text(
                              l10n.pinLockTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              l10n.pinLockSub,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            trailing: FilledButton.tonal(
                              onPressed: _showSetPinDialog,
                              child: Text(
                                l10n.pinSetButton,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                        else ...[
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 2,
                            ),
                            secondary: const Icon(
                              Icons.pin_rounded,
                              color: AppTheme.primary,
                            ),
                            title: Text(
                              l10n.pinLockTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              l10n.pinLockSub,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            value: _securityService.isPinEnabled,
                            activeThumbColor: AppTheme.primary,
                            onChanged: (val) {
                              _securityService.togglePinEnabled(val);
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _showChangePinDialog,
                                    icon: const Icon(Icons.edit_rounded, size: 14),
                                    label: Text(l10n.pinChangeButton, style: const TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _showDisablePinDialog,
                                    icon: const Icon(Icons.delete_outline_rounded, size: 14),
                                    label: Text(l10n.pinDisableButton, style: const TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.danger,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // SECTION 4: SINKRONISASI SERVER & KONEKSI
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
