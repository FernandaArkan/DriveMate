import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivemate/theme/app_theme.dart';

void main() {
  testWidgets('Render reminder dialog on small screen without any overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String category = 'Servis';
    int? selectedVehicleId = 1;
    bool preferExactAlarm = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) {
                        return StatefulBuilder(
                          builder: (context, setDialogState) {
                            const dateStr = '25 Oktober 2026';
                            const timeStr = '09:00 WIB';

                            return AlertDialog(
                              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22)),
                              title: const Row(
                                children: [
                                  Icon(Icons.add_alarm_rounded, color: AppTheme.primary),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Atur Pengingat Servis',
                                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
                                        initialValue: category,
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
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          'Ganti Oli Mesin',
                                          'Servis 10.000 km',
                                          'Pajak STNK',
                                          'Cek Aki & Ban',
                                        ].map((template) {
                                          return ActionChip(
                                            label: Text(template,
                                                style: const TextStyle(fontSize: 11)),
                                            backgroundColor: const Color(0xFFEBF2FA),
                                            side: BorderSide.none,
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            onPressed: () {
                                              setDialogState(() {
                                                titleController.text = template;
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 10),
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
                                      const SizedBox(height: 10),
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
                                        items: const [
                                          DropdownMenuItem<int>(
                                            value: 1,
                                            child: Text('Honda Civic (AB 1234 CD)', overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setDialogState(() => selectedVehicleId = val);
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 12),
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
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF4F7FB),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.calendar_today_rounded,
                                                      size: 15, color: AppTheme.primary),
                                                  SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      dateStr,
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF4F7FB),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.access_time_rounded,
                                                      size: 15, color: AppTheme.primary),
                                                  SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      timeStr,
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
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
                                        onChanged: (val) {
                                          setDialogState(() => preferExactAlarm = val);
                                        },
                                      ),
                                      const SizedBox(height: 8),
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
                                          hintText: 'Misal: Siapkan oli 4 liter & filter oli original.',
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
                                      const SizedBox(height: 10),
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
                                  onPressed: () => Navigator.pop(dialogCtx, true),
                                  child: const Text('Jadwalkan'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Atur Pengingat Servis'), findsOneWidget);
    expect(find.text('Ganti Oli Mesin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
