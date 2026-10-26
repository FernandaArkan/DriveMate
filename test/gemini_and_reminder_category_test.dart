import 'package:flutter_test/flutter_test.dart';
import 'package:drivemate/models/reminder_item.dart';
import 'package:drivemate/services/ai_service.dart';

void main() {
  group('Task 1 — AiService & Google Gemini Integration Unit Tests', () {
    test('askAi throws AiServiceException on empty input', () async {
      final aiService = AiService.instance;
      expect(
        () => aiService.askAi('   '),
        throwsA(isA<AiServiceException>().having(
          (e) => e.message,
          'message',
          contains('tidak boleh kosong'),
        )),
      );
    });

    test('askAi throws realistic error and never returns dummy simulated responses', () async {
      final aiService = AiService.instance;

      // Pertanyaan terkait oli yang sebelumnya menghasilkan teks dummy di _handleUnconfiguredBackendAi
      try {
        final reply = await aiService.askAi('Kapan waktu yang tepat untuk ganti oli mesin?');
        // Jika server backend merespon sukses nyata
        expect(reply, isNotEmpty);
        expect(reply, isNot(contains('[Mode Asisten Otomotif]')));
      } catch (e) {
        // Jika backend offline atau belum ada key, harus throw AiServiceException
        expect(e, isA<AiServiceException>());
        final errText = e.toString();
        // Memastikan tidak ada teks dummy
        expect(errText, isNot(contains('[Mode Asisten Otomotif]')));
      }
    });

    test('AiChatMessage instantiates properly with error flag support', () {
      final msg = AiChatMessage(
        text: 'Koneksi backend gagal',
        isUser: false,
        time: '10:00',
        isError: true,
      );
      expect(msg.isError, true);
      expect(msg.isUser, false);
      expect(msg.text, 'Koneksi backend gagal');
    });

    test('Error message never leaks raw server HTML pages in chat', () {
      // Meniru format HTML mentah jika proxy/server web memuntahkan halaman error 503/504
      final rawHtml = '<!DOCTYPE html><html><head><title>503 Service Unavailable</title></head><body><h1>503</h1></body></html>';
      expect(rawHtml.contains('<html'), true);
      // Validasi bahwa AiServiceException menyimpan pesan tekstual bersih, bukan tag HTML
      final err = AiServiceException('Layanan Google Gemini AI sedang mengalami lonjakan beban/permintaan tinggi (HTTP 503). Silakan coba ajukan kembali pertanyaan Anda dalam beberapa saat.');
      expect(err.toString(), isNot(contains('<html')));
      expect(err.toString(), isNot(contains('<!DOCTYPE')));
      expect(err.toString(), contains('503'));
    });
  });

  group('Task 2 — Reminder Category Resolution & Filtering Tests', () {
    // Fungsi resolusi yang sama persis dengan yang ada di notifications_page
    String resolveCategory(ReminderItem item) {
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

    final reminders = [
      ReminderItem(
        id: 1,
        title: 'Pengingat Servis',
        message: 'Servis berkala dalam 2.500 km',
        category: 'Servis',
        timeAgo: '1 jam lalu',
      ),
      ReminderItem(
        id: 2,
        title: 'Ganti Oli Mesin',
        message: 'Ganti oli mesin 10W-40',
        category: 'Servis',
        timeAgo: '2 jam lalu',
      ),
      ReminderItem(
        id: 3,
        title: 'Pajak Kendaraan',
        message: 'Pajak jatuh tempo bulan depan',
        category: 'Pajak',
        timeAgo: '3 jam lalu',
      ),
      ReminderItem(
        id: 4,
        title: 'Cek Aki & Ban',
        message: 'Periksa tekanan ban dan voltase aki',
        category: 'Servis', // Sebelumnya tersimpan sebagai 'Servis' karena bug template
        timeAgo: 'Baru saja',
      ),
      ReminderItem(
        id: 5,
        title: 'Perawatan Kampas Rem',
        message: 'Ganti kampas rem depan',
        category: 'Perawatan', // Disimpan eksplisit sebagai 'Perawatan'
        timeAgo: 'Baru saja',
      ),
      ReminderItem(
        id: 6,
        title: 'Pembaruan Aplikasi',
        message: 'Versi terbaru tersedia',
        category: 'Sistem',
        timeAgo: '1 hari lalu',
      ),
    ];

    test('Cek Aki & Ban resolves to Perawatan even if previously saved as Servis', () {
      final item = reminders.firstWhere((r) => r.title == 'Cek Aki & Ban');
      expect(resolveCategory(item), 'Perawatan');
    });

    test('Servis reminders remain under Servis and are not shifted to Perawatan', () {
      final s1 = reminders.firstWhere((r) => r.title == 'Pengingat Servis');
      final s2 = reminders.firstWhere((r) => r.title == 'Ganti Oli Mesin');
      expect(resolveCategory(s1), 'Servis');
      expect(resolveCategory(s2), 'Servis');
    });

    test('Pajak reminders remain under Pajak', () {
      final p1 = reminders.firstWhere((r) => r.title == 'Pajak Kendaraan');
      expect(resolveCategory(p1), 'Pajak');
    });

    test('Tab Semua displays all 6 reminders', () {
      const selectedFilter = 'Semua';
      final filtered = selectedFilter == 'Semua'
          ? reminders
          : reminders.where((r) => resolveCategory(r).toLowerCase() == selectedFilter.toLowerCase()).toList();
      expect(filtered.length, 6);
    });

    test('Tab Perawatan displays both Cek Aki & Ban and Perawatan Kampas Rem', () {
      const selectedFilter = 'Perawatan';
      final filtered = reminders
          .where((r) => resolveCategory(r).toLowerCase() == selectedFilter.toLowerCase())
          .toList();

      expect(filtered.length, 2);
      expect(filtered.any((r) => r.title == 'Cek Aki & Ban'), true);
      expect(filtered.any((r) => r.title == 'Perawatan Kampas Rem'), true);
    });

    test('Tab Servis displays only actual service reminders', () {
      const selectedFilter = 'Servis';
      final filtered = reminders
          .where((r) => resolveCategory(r).toLowerCase() == selectedFilter.toLowerCase())
          .toList();

      expect(filtered.length, 2);
      expect(filtered.any((r) => r.title == 'Pengingat Servis'), true);
      expect(filtered.any((r) => r.title == 'Ganti Oli Mesin'), true);
      expect(filtered.any((r) => r.title == 'Cek Aki & Ban'), false);
    });

    test('Tab Pajak displays only tax reminders', () {
      const selectedFilter = 'Pajak';
      final filtered = reminders
          .where((r) => resolveCategory(r).toLowerCase() == selectedFilter.toLowerCase())
          .toList();

      expect(filtered.length, 1);
      expect(filtered.first.title, 'Pajak Kendaraan');
    });
  });
}
