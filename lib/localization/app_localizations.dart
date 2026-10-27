import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('id', 'ID'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('id', 'ID'),
    Locale('en', 'US'),
  ];

  bool get isEnglish => locale.languageCode == 'en';

  // Common
  String get appName => 'DriveMate';
  String get cancel => isEnglish ? 'Cancel' : 'Batal';
  String get save => isEnglish ? 'Save' : 'Simpan';
  String get close => isEnglish ? 'Close' : 'Tutup';
  String get delete => isEnglish ? 'Delete' : 'Hapus';
  String get reset => isEnglish ? 'Reset' : 'Reset';

  // Navigation
  String get navHome => 'Home';
  String get navVehicles => isEnglish ? 'Vehicles' : 'Kendaraan';
  String get navTrips => isEnglish ? 'Trips' : 'Perjalanan';
  String get navAi => isEnglish ? 'AI' : 'AI';
  String get navProfile => isEnglish ? 'Profile' : 'Profil';

  // Profile Page
  String get profileTitle => isEnglish ? 'Profile' : 'Profil';
  String get editProfile => isEnglish ? 'Edit Profile' : 'Edit Profil';
  String get profileUpdatedSuccess =>
      isEnglish ? 'Profile updated successfully.' : 'Profil berhasil diperbarui.';
  String get fullName => isEnglish ? 'Full Name' : 'Nama Lengkap';
  String get registeredEmail =>
      isEnglish ? 'Registered Email' : 'Email Terdaftar';
  String get whatsappNumber =>
      isEnglish ? 'WhatsApp Number' : 'Nomor WhatsApp';
  String get accountStatus => isEnglish ? 'Account Status' : 'Status Akun';
  String get verifiedActive =>
      isEnglish ? 'Verified (Active)' : 'Terverifikasi (Aktif)';
  String get userIdLabel => isEnglish ? 'User ID' : 'ID Pengguna';
  String get miniGameTitle =>
      isEnglish ? 'Play 2D Mini-Game' : 'Main Mini-Game 2D';
  String get miniGameSubtitle => isEnglish
      ? 'Vehicle Runner • Avoid obstacles on the road'
      : 'Vehicle Runner • Hindari rintangan di jalan';
  String get menuUserData =>
      isEnglish ? 'User Profile Data' : 'Data Pengguna';
  String get menuVehicles => isEnglish ? 'Vehicle Data' : 'Data Kendaraan';
  String get menuSettings => isEnglish ? 'Settings' : 'Pengaturan';
  String get menuSecurity =>
      isEnglish ? 'Security & Biometrics' : 'Keamanan & Biometrik';
  String get menuHistory =>
      isEnglish ? 'Activity History' : 'Riwayat Aktivitas';
  String get menuFeedback =>
      isEnglish ? 'Feedback & Suggestions' : 'Kesan & Pesan';
  String get menuFaq => isEnglish ? 'Help & FAQ' : 'Bantuan & FAQ';
  String get menuAbout => isEnglish ? 'About Application' : 'Tentang Aplikasi';
  String get logout => isEnglish ? 'Log Out' : 'Logout';
  String get logoutConfirmTitle =>
      isEnglish ? 'Confirm Log Out' : 'Konfirmasi Logout';
  String get logoutConfirmMessage => isEnglish
      ? 'Are you sure you want to log out of your DriveMate account?'
      : 'Apakah Anda yakin ingin keluar dari akun DriveMate Anda?';
  String get biometricLogin => isEnglish
      ? 'Fingerprint / Face ID Login'
      : 'Login dengan Sidik Jari / Wajah';
  String get biometricSubtitle => isEnglish
      ? 'Open the app faster and securely'
      : 'Buka aplikasi lebih cepat dan aman';
  String get changePassword =>
      isEnglish ? 'Change Password' : 'Ubah Password';
  String get changePasswordSubtitle => isEnglish
      ? 'Update your account password periodically'
      : 'Perbarui kata sandi akun Anda secara berkala';
  String get faqTitle => isEnglish ? 'Help & FAQ' : 'Bantuan & FAQ';
  String get faqQ1 => isEnglish
      ? 'Q: How do I add a new vehicle?'
      : 'Q: Bagaimana cara menambah kendaraan?';
  String get faqA1 => isEnglish
      ? 'A: Open the Vehicles tab, then tap the "+ Add Vehicle" button at the top.'
      : 'A: Buka tab Kendaraan, lalu tekan tombol "+ Tambah Kendaraan" di bagian atas.';
  String get faqQ2 => isEnglish
      ? 'Q: Is service history data secure?'
      : 'Q: Apakah riwayat servis aman?';
  String get faqA2 => isEnglish
      ? 'A: Yes, each digital service record is encrypted with a SHA-256 hash verifying data integrity.'
      : 'A: Ya, setiap buku servis digital dienkripsi dengan algoritma hashing SHA-256 yang memverifikasi integritas data.';
  String get aboutDescription => isEnglish
      ? 'DriveMate — Personal Vehicle Assistant is a smart automotive assistant app for tracking maintenance, monitoring routes and sensors, AI assistance, and digital service blockchain demonstration.'
      : 'DriveMate — Personal Vehicle Assistant adalah aplikasi asisten pintar otomotif untuk mencatat perawatan, memantau rute dan sensor, asisten AI, serta demonstrasi blockchain servis digital.';

  // Settings Page
  String get settingsTitle => isEnglish ? 'Settings' : 'Pengaturan';
  String get sectionNotifications =>
      isEnglish ? 'Notifications & Reminders' : 'Notifikasi & Pengingat';
  String get periodicServiceReminder =>
      isEnglish ? 'Periodic Service Reminder' : 'Pengingat Servis Berkala';
  String get periodicServiceReminderSub => isEnglish
      ? 'Automatic alert when mileage approaches service schedule'
      : 'Peringatan otomatis saat jarak tempuh mendekati jadwal servis';
  String get taxReminder =>
      isEnglish ? 'Vehicle Tax Reminder' : 'Pengingat Pajak Kendaraan';
  String get taxReminderSub => isEnglish
      ? 'Notification before vehicle registration and tax expiration'
      : 'Notifikasi sebelum masa berlaku STNK dan pajak habis';
  String get weatherSensorWarning =>
      isEnglish ? 'Weather & Sensor Warning' : 'Peringatan Cuaca & Sensor';
  String get weatherSensorWarningSub => isEnglish
      ? 'Adverse weather alerts during active trips'
      : 'Pemberitahuan cuaca buruk saat perjalanan aktif';
  String get sectionPreferences =>
      isEnglish ? 'App Preferences' : 'Preferensi Aplikasi';
  String get language => isEnglish ? 'Language' : 'Bahasa';
  String get distanceUnit => isEnglish ? 'Distance Unit' : 'Satuan Jarak';
  String get sectionSync => isEnglish
      ? 'Synchronization & Backend Server'
      : 'Sinkronisasi & Server Backend';
  String get serverApi =>
      isEnglish ? 'Server API (Host Server):' : 'Server API (Laptop Server):';
  String get syncNow => isEnglish ? 'Sync Now' : 'Sinkronkan Sekarang';
  String get syncing => isEnglish ? 'Syncing...' : 'Menyinkronkan...';
  String get startSyncMessage => isEnglish
      ? 'Starting data synchronization with backend server...'
      : 'Memulai sinkronisasi data dengan server backend...';
  String get resetSettings => isEnglish
      ? 'Restore Default Settings'
      : 'Kembalikan Pengaturan Default';
  String get resetDialogTitle =>
      isEnglish ? 'Reset Settings' : 'Reset Pengaturan';
  String get resetDialogContent => isEnglish
      ? 'Do you want to reset all preferences to their default values?'
      : 'Apakah Anda ingin mengembalikan semua preferensi ke pengaturan awal?';
  String get resetSuccess => isEnglish
      ? 'Settings have been restored to default.'
      : 'Pengaturan telah dikembalikan ke default.';
  String get languageIndonesianLabel => 'Bahasa Indonesia';
  String get languageEnglishLabel => 'English';

  // Kesan & Pesan (Feedback)
  String get feedbackTitle =>
      isEnglish ? 'Feedback & Suggestions' : 'Kesan & Pesan';
  String get feedbackCardTitle =>
      isEnglish ? 'Your Feedback & Impressions' : 'Kesan & Masukan Anda';
  String get feedbackCardDesc => isEnglish
      ? 'Share your experience using DriveMate as well as suggestions, feedback, or critiques to help us improve future versions.'
      : 'Sampaikan kesan Anda selama menggunakan DriveMate serta pesan, kritik, atau saran untuk pengembangan aplikasi ke depannya.';
  String get feedbackLocalStorageNote => isEnglish
      ? 'Note: Your feedback is stored locally on this device (offline storage).'
      : 'Catatan: Masukan Anda disimpan secara lokal di perangkat ini (offline storage).';
  String get feedbackKesanLabel =>
      isEnglish ? 'Usage Impressions' : 'Kesan Penggunaan';
  String get feedbackKesanHint => isEnglish
      ? 'e.g. Modern and easy-to-use UI, service tracking is very helpful...'
      : 'Misal: Tampilan aplikasi modern dan rapi, pencatatan servis sangat membantu...';
  String get feedbackKesanError => isEnglish
      ? 'Please enter your impressions (cannot be empty)'
      : 'Kesan tidak boleh kosong';
  String get feedbackPesanLabel =>
      isEnglish ? 'Messages & Suggestions' : 'Pesan, Saran & Masukan';
  String get feedbackPesanHint => isEnglish
      ? 'e.g. Hopefully in the future official workshop integration is added...'
      : 'Misal: Harapannya ke depan ditambahkan rekomendasi bengkel resmi terdekat...';
  String get feedbackPesanError => isEnglish
      ? 'Please enter your message/suggestions (cannot be empty)'
      : 'Pesan & saran tidak boleh kosong';
  String get feedbackRatingLabel =>
      isEnglish ? 'Satisfaction Rating' : 'Tingkat Kepuasan';
  String get feedbackSubmitBtn =>
      isEnglish ? 'Save Feedback' : 'Simpan Kesan & Pesan';
  String get feedbackSaveSuccess => isEnglish
      ? 'Your feedback has been saved locally on this device.'
      : 'Kesan dan pesan Anda berhasil disimpan di perangkat.';
  String get feedbackHistoryTitle =>
      isEnglish ? 'Saved Feedback History' : 'Riwayat Kesan & Pesan Tersimpan';
  String get feedbackEmptyHistory => isEnglish
      ? 'No feedback recorded yet. Write your thoughts above!'
      : 'Belum ada kesan dan pesan yang tersimpan. Tuliskan masukan Anda di atas!';
  String get feedbackDeleteConfirmTitle =>
      isEnglish ? 'Delete Feedback' : 'Hapus Masukan';
  String get feedbackDeleteConfirmMsg => isEnglish
      ? 'Are you sure you want to delete this saved feedback?'
      : 'Apakah Anda yakin ingin menghapus catatan masukan ini?';
  String get feedbackDeletedSuccess => isEnglish
      ? 'Feedback successfully deleted.'
      : 'Kesan dan pesan berhasil dihapus.';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['id', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
