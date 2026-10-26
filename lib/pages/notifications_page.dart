import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/reminder_item.dart';
import '../models/vehicle.dart';
import '../repositories/vehicle_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final NotificationService _notifService = NotificationService.instance;
  final VehicleRepository _vehicleRepo = VehicleRepository.instance;

  List<ReminderItem> _reminders = [];
  bool _isLoading = true;
  String _selectedFilter = 'Semua';
  bool _isNotificationPermissionGranted = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionStatus();
    _loadReminders();
    _vehicleRepo.loadVehicles();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Saat pengguna kembali dari Pengaturan OS, periksa status izin secara otomatis
      _checkPermissionStatus();
    }
  }

  Future<void> _checkPermissionStatus() async {
    final granted = await _notifService.areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _isNotificationPermissionGranted = granted;
      });
    }
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

  /// Menentukan kategori pengingat secara tepat berdasarkan jenis pengingat.
  /// Memastikan pengingat yang dibuat (misalnya untuk perawatan ban, aki, rem)
  /// muncul pada kategori 'Perawatan' dan tidak salah masuk atau hilang.
  String _resolveCategory(ReminderItem item) {
    final cat = item.category.trim();
    final catLower = cat.toLowerCase();
    if (catLower == 'perawatan') return 'Perawatan';
    if (catLower == 'pajak') return 'Pajak';
    if (catLower == 'sistem') return 'Sistem';

    final titleLower = item.title.toLowerCase();
    if (titleLower.contains('aki') ||
        titleLower.contains('ban') ||
        titleLower.contains('rem') ||
        titleLower.contains('perawatan')) {
      return 'Perawatan';
    }
    if (titleLower.contains('pajak') || titleLower.contains('stnk')) {
      return 'Pajak';
    }

    return cat.isNotEmpty ? cat : 'Servis';
  }

  /// Menentukan kategori awal dari judul pengingat
  String _resolveCategoryFromTitle(String title, {String fallback = 'Servis'}) {
    final titleLower = title.toLowerCase();
    if (titleLower.contains('aki') ||
        titleLower.contains('ban') ||
        titleLower.contains('rem') ||
        titleLower.contains('perawatan')) {
      return 'Perawatan';
    }
    if (titleLower.contains('pajak') || titleLower.contains('stnk')) {
      return 'Pajak';
    }
    if (titleLower.contains('servis') || titleLower.contains('oli')) {
      return 'Servis';
    }
    return fallback;
  }

  List<ReminderItem> get _filteredList {
    if (_selectedFilter == 'Semua') return _reminders;
    return _reminders
        .where((r) =>
            _resolveCategory(r).toLowerCase() == _selectedFilter.toLowerCase())
        .toList();
  }

  Vehicle? _findVehicle(int? vehicleId) {
    if (vehicleId == null || _vehicleRepo.vehicles.isEmpty) return null;
    final matches = _vehicleRepo.vehicles.where((v) => v.id == vehicleId);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Menampilkan dialog edukasi izin sebelum memanggil request izin sistem
  Future<bool> _ensureNotificationPermission() async {
    final currentlyEnabled = await _notifService.areNotificationsEnabled();
    if (currentlyEnabled) {
      setState(() => _isNotificationPermissionGranted = true);
      return true;
    }

    if (!mounted) return false;

    // Tampilkan dialog penjelasan ramah pengguna mengenai kebutuhan izin
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded,
                color: AppTheme.primary, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Izin Notifikasi Servis',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DriveMate memerlukan izin notifikasi agar sistem operasi dapat memunculkan alarm '
              'pengingat servis berkala, ganti oli, dan perpanjangan pajak tepat waktu.',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'Pengingat ini dikelola langsung oleh sistem Android (AlarmManager) dan akan tetap '
              'berbunyi meskipun aplikasi DriveMate sedang ditutup atau perangkat dalam keadaan idle.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nanti Saja'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aktifkan Izin'),
          ),
        ],
      ),
    );

    if (proceed != true) {
      return false;
    }

    final granted = await _notifService.requestPermissions();
    if (mounted) {
      setState(() => _isNotificationPermissionGranted = granted);
    }

    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Izin notifikasi belum aktif. Anda tetap dapat menyimpan jadwal, namun '
            'notifikasi tidak dapat ditampilkan oleh sistem sampai izin diaktifkan di Pengaturan.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Pengaturan',
            textColor: AppTheme.cyan,
            onPressed: () => _notifService.openNotificationSettings(),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }

    return granted;
  }

  /// Pengujian notifikasi instan langsung untuk memverifikasi channel notifikasi
  Future<void> _testImmediateNotification() async {
    final permitted = await _ensureNotificationPermission();
    if (!permitted && !_isNotificationPermissionGranted) return;

    await _notifService.showNotification(
      id: 9999,
      title: 'DriveMate • Uji Notifikasi Langsung',
      body:
          'Channel notifikasi pengingat servis aktif dan dapat menerima pesan sistem!',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifikasi uji instan telah dikirim ke status bar.'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Pengujian notifikasi terjadwal (5 detik dari sekarang) untuk membuktikan alarm berjalan saat app ditutup
  Future<void> _scheduleQuickTestNotification() async {
    final permitted = await _ensureNotificationPermission();
    if (!permitted && !_isNotificationPermissionGranted) return;

    final testId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final scheduledTime = DateTime.now().add(const Duration(seconds: 5));

    final success = await _notifService.scheduleNotification(
      id: testId,
      title: 'DriveMate • Uji Pengingat OS Latar Belakang',
      body:
          'Pengingat terjadwal berhasil dieksekusi oleh AlarmManager sistem Android!',
      scheduledDate: scheduledTime,
      preferExact: true,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifikasi uji coba dijadwalkan dalam 5 detik. Anda dapat menutup atau meminimalkan aplikasi '
            'sekarang untuk membuktikan notifikasi tetap muncul saat aplikasi tertutup!',
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menjadwalkan notifikasi uji coba.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Dialog form untuk menambah atau mengedit pengingat servis
  Future<void> _showScheduleReminderDialog({ReminderItem? existingItem}) async {
    await initializeDateFormatting('id_ID', null);
    await _ensureNotificationPermission();

    final isEditing = existingItem != null;
    final titleController =
        TextEditingController(text: existingItem?.title ?? '');
    final messageController =
        TextEditingController(text: existingItem?.message ?? '');

    String category = existingItem != null ? _resolveCategory(existingItem) : 'Servis';
    int? selectedVehicleId = existingItem?.vehicleId ??
        _vehicleRepo.primaryVehicle?.id ??
        (_vehicleRepo.vehicles.isNotEmpty
            ? _vehicleRepo.vehicles.first.id
            : null);

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    bool preferExactAlarm = false;

    // Parse tanggal awal jika sedang mengedit
    if (isEditing && existingItem.targetDate != null) {
      final parsed = _notifService.parseDateTimeFlexible(existingItem.targetDate!);
      if (parsed != null) {
        selectedDate = parsed;
        selectedTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      }
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dateStr =
                DateFormat('dd MMMM yyyy', 'id_ID').format(selectedDate);
            final timeStr =
                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')} WIB';

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              title: Row(
                children: [
                  Icon(
                    isEditing
                        ? Icons.edit_calendar_rounded
                        : Icons.add_alarm_rounded,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Ubah Pengingat Servis'
                          : 'Atur Pengingat Servis',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 380,
                  maxHeight: MediaQuery.sizeOf(dialogCtx).height * 0.65,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kategori
                      const Text(
                        'Kategori Pengingat',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 5),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        isDense: true,
                        key: ValueKey(category),
                        initialValue: const ['Servis', 'Pajak', 'Perawatan', 'Sistem'].contains(category) ? category : 'Servis',
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF4F7FB),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Servis',
                              child: Text('Servis Berkala / Ganti Oli', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(
                              value: 'Pajak',
                              child: Text('Pajak Kendaraan (PKB/STNK)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(
                              value: 'Perawatan',
                              child: Text('Perawatan Ban, Aki & Rem', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(
                              value: 'Sistem',
                              child: Text('Pemeriksaan Umum', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => category = val);
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // Template Pintasan Judul
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: const [
                          {'title': 'Ganti Oli Mesin', 'category': 'Servis'},
                          {'title': 'Servis 10.000 km', 'category': 'Servis'},
                          {'title': 'Pajak STNK', 'category': 'Pajak'},
                          {'title': 'Cek Aki & Ban', 'category': 'Perawatan'},
                        ].map((template) {
                          return ActionChip(
                            label: Text(template['title']!,
                                style: const TextStyle(fontSize: 11)),
                            backgroundColor: const Color(0xFFEBF2FA),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            onPressed: () {
                              setDialogState(() {
                                titleController.text = template['title']!;
                                category = template['category']!;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // Judul
                      const Text(
                        'Judul Pengingat',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'Misal: Ganti Oli Mesin 10W-40',
                          hintStyle: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: const Color(0xFFF4F7FB),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Pilih Kendaraan
                      if (_vehicleRepo.vehicles.isNotEmpty) ...[
                        const Text(
                          'Pilih Kendaraan',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 5),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          isDense: true,
                          initialValue: selectedVehicleId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF4F7FB),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: _vehicleRepo.vehicles.map((v) {
                            return DropdownMenuItem<int>(
                              value: v.id,
                              child: Text(
                                '${v.brand} ${v.name} (${v.plate})',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedVehicleId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Tanggal & Waktu
                      const Text(
                        'Jadwal Alarm Notifikasi',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365 * 3)),
                                );
                                if (picked != null) {
                                  setDialogState(
                                      () => selectedDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F7FB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded,
                                        size: 15, color: AppTheme.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        dateStr,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime,
                                );
                                if (picked != null) {
                                  setDialogState(
                                      () => selectedTime = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F7FB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded,
                                        size: 15, color: AppTheme.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        timeStr,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Mode Presisi Exact Alarm (Opsional)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Mode Presisi Waktu (Exact Alarm)',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary),
                        ),
                        subtitle: const Text(
                          'Bunyikan pada menit tepat (memerlukan izin alarm sistem pada Android 13+)',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.textSecondary),
                        ),
                        value: preferExactAlarm,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (val) async {
                          if (val) {
                            await _notifService.requestExactAlarmsPermission();
                          }
                          setDialogState(() => preferExactAlarm = val);
                        },
                      ),
                      const SizedBox(height: 8),

                      // Catatan / Instruksi
                      const Text(
                        'Catatan / Instruksi Tambahan (Opsional)',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: messageController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText:
                              'Misal: Siapkan oli 4 liter & filter oli original.',
                          hintStyle: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: const Color(0xFFF4F7FB),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Info Alarm Latar Belakang
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: Color(0xFF2563EB), size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Alarm dijadwalkan ke AlarmManager sistem OS. Notifikasi akan berbunyi tepat waktu meskipun aplikasi sedang ditutup.',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF1E40AF),
                                    height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Judul pengingat wajib diisi.')),
                      );
                      return;
                    }
                    Navigator.pop(dialogCtx, true);
                  },
                  child: Text(isEditing ? 'Simpan Perubahan' : 'Jadwalkan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final scheduledDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      final formattedTarget =
          '${DateFormat('yyyy-MM-dd').format(scheduledDateTime)} ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

      final title = titleController.text.trim();
      final effectiveCategory = (category == 'Servis')
          ? _resolveCategoryFromTitle(title, fallback: category)
          : category;
      final message = messageController.text.trim().isNotEmpty
          ? messageController.text.trim()
          : 'Jadwal $effectiveCategory kendaraan Anda telah tiba. Silakan lakukan perawatan berkala.';

      int reminderId;

      if (isEditing && existingItem.id != null) {
        reminderId = existingItem.id!;
        final updatedItem = ReminderItem(
          id: reminderId,
          vehicleId: selectedVehicleId,
          title: title,
          message: message,
          category: effectiveCategory,
          timeAgo: 'Diperbarui',
          targetDate: formattedTarget,
          isRead: false,
        );

        await _dbHelper.updateReminder(updatedItem);
      } else {
        final newItem = ReminderItem(
          vehicleId: selectedVehicleId,
          title: title,
          message: message,
          category: effectiveCategory,
          timeAgo: 'Dijadwalkan',
          targetDate: formattedTarget,
          isRead: false,
        );

        reminderId = await _dbHelper.addReminder(newItem);
      }

      // Jadwalkan notifikasi lokal di sistem Android OS (bahkan saat aplikasi ditutup)
      final scheduledSuccess = await _notifService.scheduleNotification(
        id: reminderId,
        title: 'DriveMate • $title',
        body: message,
        scheduledDate: scheduledDateTime,
        preferExact: preferExactAlarm,
      );

      await _loadReminders();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Jadwal pengingat "$title" berhasil diperbarui pada '
                    '${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(scheduledDateTime)} WIB.'
                : 'Pengingat "$title" berhasil dijadwalkan pada '
                    '${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(scheduledDateTime)} WIB.',
          ),
          backgroundColor:
              scheduledSuccess ? AppTheme.success : AppTheme.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Menghapus pengingat dan membatalkan alarm di sistem OS
  Future<void> _deleteReminder(ReminderItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Hapus Pengingat',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          'Batalkan jadwal dan hapus alarm notifikasi untuk "${item.title}"?',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus & Batalkan Alarm'),
          ),
        ],
      ),
    );

    if (confirm == true && item.id != null) {
      await _dbHelper.deleteReminder(item.id!);
      await _notifService.cancelNotification(item.id!);
      await _loadReminders();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Pengingat dan jadwal alarm di OS berhasil dibatalkan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Notifikasi & Pengingat Servis',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu Uji Notifikasi',
            icon: const Icon(Icons.flash_on_rounded, color: AppTheme.primary),
            onSelected: (val) {
              if (val == 'quick_5s') {
                _scheduleQuickTestNotification();
              } else if (val == 'instant') {
                _testImmediateNotification();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'quick_5s',
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text('Uji Alarm OS (5 Detik Latar Belakang)', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'instant',
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 18, color: AppTheme.success),
                    SizedBox(width: 8),
                    Text('Uji Notifikasi Instan', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alarm_rounded, size: 20),
        label: const Text(
          'Atur Pengingat',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        onPressed: () => _showScheduleReminderDialog(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
          children: [
            // Status Izin Notifikasi OS (Banner Transparan & Ramah)
            _buildPermissionBanner(),

            const SizedBox(height: 14),

            // Filter Tabs (Semua, Servis, Pajak, Perawatan, Sistem)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    ['Semua', 'Servis', 'Pajak', 'Perawatan', 'Sistem']
                        .map((filter) {
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
                        color:
                            isSelected ? Colors.white : AppTheme.textPrimary,
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

            const SizedBox(height: 18),

            if (_isLoading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator()))
            else if (_filteredList.isEmpty)
              _buildEmptyState()
            else
              ..._filteredList.map((item) => _buildNotificationCard(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    if (_isNotificationPermissionGranted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF16A34A), size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alarm Latar Belakang Aktif',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Color(0xFF15803D)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Jadwal pengingat servis dikelola langsung oleh sistem Android OS.',
                    style: TextStyle(fontSize: 10, color: Color(0xFF166534)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded,
                  size: 16, color: Color(0xFF16A34A)),
              tooltip: 'Info Alarm',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    title: const Text('Cara Kerja Pengingat Latar Belakang',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    content: const Text(
                      '• Pengingat DriveMate menggunakan AlarmManager sistem Android dengan inexact allow while idle.\n\n'
                      '• Notifikasi tetap muncul saat aplikasi diminimalkan atau ditutup secara normal.\n\n'
                      '• Waktu kedatangan notifikasi mungkin bergeser 1-5 menit karena mekanisme Doze Mode penghemat baterai Android.\n\n'
                      '• Jika perangkat di-restart, jadwal secara otomatis dipulihkan oleh BootReceiver.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.4),
                    ),
                    actions: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Mengerti'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // Kondisi belum berizin
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_rounded,
              color: Color(0xFFD97706), size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Izin Notifikasi Belum Aktif',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Color(0xFFB45309)),
                ),
                SizedBox(height: 2),
                Text(
                  'Aktifkan izin agar alarm servis tetap berbunyi saat aplikasi tertutup.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF92400E)),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _ensureNotificationPermission(),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.alarm_off_rounded,
                size: 30, color: AppTheme.primary),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum Ada Pengingat Terjadwal',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Buat jadwal pengingat untuk servis berkala, ganti oli mesin, atau jatuh tempo pajak kendaraan Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            icon: const Icon(Icons.add_alarm_rounded, size: 16),
            label: const Text('Atur Pengingat Sekarang'),
            onPressed: () => _showScheduleReminderDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(ReminderItem item) {
    Color iconColor;
    Color iconBg;
    IconData iconData;

    final effectiveCategory = _resolveCategory(item);

    switch (effectiveCategory.toLowerCase()) {
      case 'servis':
        iconColor = AppTheme.danger;
        iconBg = AppTheme.danger.withValues(alpha: 0.12);
        iconData = Icons.build_circle_rounded;
        break;
      case 'pajak':
        iconColor = AppTheme.warning;
        iconBg = AppTheme.warning.withValues(alpha: 0.14);
        iconData = Icons.receipt_long_rounded;
        break;
      case 'perawatan':
        iconColor = const Color(0xFF8B5CF6);
        iconBg = const Color(0xFF8B5CF6).withValues(alpha: 0.12);
        iconData = Icons.car_repair_rounded;
        break;
      default:
        iconColor = AppTheme.success;
        iconBg = AppTheme.success.withValues(alpha: 0.14);
        iconData = Icons.notifications_active_rounded;
    }

    final linkedVehicle = _findVehicle(item.vehicleId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            effectiveCategory,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Detail Waktu Target & Kendaraan
          Row(
            children: [
              if (item.targetDate != null) ...[
                const Icon(Icons.access_time_filled_rounded,
                    size: 13, color: AppTheme.primary),
                const SizedBox(width: 5),
                Text(
                  item.targetDate!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ] else ...[
                Text(
                  item.timeAgo,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
              const Spacer(),
              if (linkedVehicle != null) ...[
                const Icon(Icons.directions_car_rounded,
                    size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${linkedVehicle.brand} ${linkedVehicle.name}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 8),
              ],

              // Tombol Edit
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    _showScheduleReminderDialog(existingItem: item),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined,
                      size: 16, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 6),

              // Tombol Hapus
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _deleteReminder(item),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 16, color: AppTheme.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
