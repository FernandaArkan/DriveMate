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

  // ==========================================
  // COMMON & BUTTONS
  // ==========================================
  String get appName => 'DriveMate';
  String get cancel => isEnglish ? 'Cancel' : 'Batal';
  String get save => isEnglish ? 'Save' : 'Simpan';
  String get close => isEnglish ? 'Close' : 'Tutup';
  String get delete => isEnglish ? 'Delete' : 'Hapus';
  String get reset => isEnglish ? 'Reset' : 'Reset';
  String get ok => isEnglish ? 'OK' : 'OK';
  String get back => isEnglish ? 'Back' : 'Kembali';
  String get loading => isEnglish ? 'Loading...' : 'Memuat...';
  String get error => isEnglish ? 'Error' : 'Kesalahan';
  String get success => isEnglish ? 'Success' : 'Berhasil';
  String get retry => isEnglish ? 'Retry' : 'Coba Lagi';
  String get edit => isEnglish ? 'Edit' : 'Ubah';
  String get search => isEnglish ? 'Search' : 'Cari';
  String get all => isEnglish ? 'All' : 'Semua';
  String get submit => isEnglish ? 'Submit' : 'Kirim';

  // ==========================================
  // NAVIGATION
  // ==========================================
  String get navHome => 'Home';
  String get navVehicles => isEnglish ? 'Vehicles' : 'Kendaraan';
  String get navTrips => isEnglish ? 'Trips' : 'Perjalanan';
  String get navAi => 'AI';
  String get navProfile => isEnglish ? 'Profile' : 'Profil';

  // ==========================================
  // HOME PAGE
  // ==========================================
  String get hello => isEnglish ? 'Hello' : 'Halo';
  String get homeWelcomeBack => isEnglish
      ? 'Welcome back to DriveMate!'
      : 'Selamat datang kembali di DriveMate!';
  String get quickActions => isEnglish ? 'Quick Actions' : 'Akses Cepat';
  String get quickService => isEnglish ? 'Service' : 'Servis';
  String get quickLocation => isEnglish ? 'Location' : 'Lokasi';
  String get quickAiAssistant => 'AI Assistant';
  String get quickMore => isEnglish ? 'More' : 'Lainnya';
  String get reminders => isEnglish ? 'Reminders' : 'Pengingat';
  String get viewAll => isEnglish ? 'View All' : 'Lihat Semua';
  String get noRemindersHome => isEnglish
      ? 'No active reminders currently. All service & tax schedules are on track.'
      : 'Tidak ada pengingat aktif saat ini. Semua jadwal servis & pajak terpantau aman.';
  String get dueLabel => isEnglish ? 'Due' : 'Jatuh tempo';
  String get targetLabel => isEnglish ? 'Target' : 'Target';
  String get vehicleSummary =>
      isEnglish ? 'Vehicle Summary' : 'Ringkasan Kendaraan';
  String get totalVehicles =>
      isEnglish ? 'Total Vehicles' : 'Total Kendaraan';
  String get totalServices =>
      isEnglish ? 'Total Services' : 'Total Servis';
  String get activeReminders =>
      isEnglish ? 'Active Reminders' : 'Pengingat Aktif';
  String get unitLabel => isEnglish ? 'units' : 'unit';
  String get timesLabel => isEnglish ? 'times' : 'kali';
  String get noVehicleTitle =>
      isEnglish ? 'No Vehicle Added' : 'Belum Ada Kendaraan';
  String get noVehicleDesc => isEnglish
      ? 'Add a vehicle to start tracking services, mileage, and taxes.'
      : 'Tambahkan kendaraan untuk mulai memantau servis, jarak tempuh, dan pajak.';
  String get addVehicle => isEnglish ? 'Add Vehicle' : 'Tambah Kendaraan';
  String get inGoodCondition =>
      isEnglish ? 'In good condition' : 'Dalam kondisi baik';
  String get mileage => isEnglish ? 'Mileage' : 'Jarak Tempuh';
  String get fuelLevel => isEnglish ? 'Fuel Level' : 'Bahan Bakar';
  String get moreFeatures => isEnglish ? 'More Features' : 'Fitur Lainnya';
  String get settingsMenuSub => isEnglish
      ? 'Language, currency & time zone preferences'
      : 'Preferensi bahasa, mata uang & zona waktu';
  String get historyMenuSub => isEnglish
      ? 'View all vehicle and app activities'
      : 'Pantau seluruh riwayat aktivitas aplikasi';
  String get feedbackMenuSub => isEnglish
      ? 'Share your impressions & suggestions'
      : 'Sampaikan saran dan masukan Anda';

  // ==========================================
  // VEHICLES PAGE & DIALOGS
  // ==========================================
  String get vehiclesTitle => isEnglish ? 'Vehicles' : 'Kendaraan';
  String get addVehicleBtn => isEnglish ? 'Add Vehicle' : 'Tambah Kendaraan';
  String get searchVehicleHint => isEnglish
      ? 'Search name, brand, or plate number...'
      : 'Cari nama, merek, atau plat nomor...';
  String get vehicleDetailTitle =>
      isEnglish ? 'Vehicle Details' : 'Detail Kendaraan';
  String get vehicleDocumentTitle =>
      isEnglish ? 'Vehicle Documents' : 'Dokumen Kendaraan';
  String get primaryVehicleLabel =>
      isEnglish ? 'Primary Vehicle' : 'Kendaraan Utama';
  String get secondaryVehicleLabel =>
      isEnglish ? 'Secondary Vehicle' : 'Kendaraan Tambahan';
  String get plateNumberLabel =>
      isEnglish ? 'License Plate' : 'Nomor Polisi';
  String get manufactureYearLabel =>
      isEnglish ? 'Manufacture Year' : 'Tahun Pembuatan';
  String get totalMileageLabel =>
      isEnglish ? 'Total Mileage' : 'Total Jarak Tempuh';
  String get fuelCapacityLabel =>
      isEnglish ? 'Fuel Capacity' : 'Kapasitas Bahan Bakar';
  String get lastServiceLabel =>
      isEnglish ? 'Last Service' : 'Servis Terakhir';
  String get taxDueDateLabel =>
      isEnglish ? 'Tax Due Date' : 'Jatuh Tempo Pajak';
  String get bpkbStatusLabel =>
      isEnglish ? 'BPKB Status' : 'Status BPKB';
  String get bpkbStatusVal => isEnglish
      ? 'Complete (Safely Stored)'
      : 'Lengkap (Tersimpan Aman)';
  String get stnk5YearExpiryLabel => isEnglish
      ? '5-Year Registration Expiration'
      : 'Masa Berlaku STNK 5 Thn';
  String get annualTaxLabel =>
      isEnglish ? 'Annual Tax' : 'Pajak Tahunan';
  String get insuranceLabel =>
      isEnglish ? 'Vehicle Insurance' : 'Asuransi Kendaraan';
  String get insuranceVal => 'Comprehensive (All Risk)';
  String get editVehicle => isEnglish ? 'Edit Data' : 'Edit Data';
  String get deleteVehicle => isEnglish ? 'Delete Vehicle' : 'Hapus Kendaraan';
  String get deleteVehicleConfirmTitle =>
      isEnglish ? 'Delete Vehicle' : 'Hapus Kendaraan';
  String deleteVehicleConfirmContent(String brand, String name, String plate) =>
      isEnglish
          ? 'Are you sure you want to delete $brand $name ($plate) from the database?'
          : 'Apakah Anda yakin ingin menghapus $brand $name ($plate) dari database?';
  String get vehicleAddedSuccess => isEnglish
      ? 'Vehicle added to database successfully.'
      : 'Kendaraan berhasil ditambahkan ke database.';
  String get vehicleUpdatedSuccess => isEnglish
      ? 'Vehicle data updated successfully.'
      : 'Data kendaraan berhasil diperbarui.';
  String get vehicleDeletedSuccess => isEnglish
      ? 'Vehicle deleted successfully.'
      : 'Kendaraan berhasil dihapus.';
  String get vehicleProcessFailed => isEnglish
      ? 'Failed to process vehicle data.'
      : 'Gagal memproses data kendaraan.';
  String get vehicleDeleteFailed => isEnglish
      ? 'Failed to delete vehicle.'
      : 'Gagal menghapus kendaraan.';
  String get noVehicleHeader =>
      isEnglish ? 'No vehicles yet' : 'Belum ada kendaraan';
  String get noVehicleSub => isEnglish
      ? 'Add your vehicle to start tracking and recording maintenance.'
      : 'Tambahkan kendaraan Anda untuk mulai memantau dan mencatat servis.';
  String get forVehiclePrefix => isEnglish ? 'For' : 'Untuk';
  String get distancePrefix => isEnglish ? 'Distance' : 'Jarak';
  String get fuelPrefix => isEnglish ? 'Fuel' : 'Bahan Bakar';

  // Vehicle Form Dialog
  String get dialogAddVehicleTitle =>
      isEnglish ? 'Add New Vehicle' : 'Tambah Kendaraan Baru';
  String get dialogEditVehicleTitle =>
      isEnglish ? 'Update Vehicle Data' : 'Perbarui Data Kendaraan';
  String get formVehicleName =>
      isEnglish ? 'Vehicle Model Name' : 'Nama Model Kendaraan';
  String get formVehicleBrand =>
      isEnglish ? 'Vehicle Brand' : 'Merek Kendaraan';
  String get formVehicleYear =>
      isEnglish ? 'Vehicle Year' : 'Tahun Kendaraan';
  String get formVehiclePlate =>
      isEnglish ? 'License Plate' : 'Plat Nomor';
  String get formVehicleMileage =>
      isEnglish ? 'Mileage (km)' : 'Jarak Tempuh (km)';
  String get formVehicleFuel =>
      isEnglish ? 'Fuel Level (%)' : 'Level Bahan Bakar (%)';
  String formRequiredError(String field) =>
      isEnglish ? '$field is required.' : '$field wajib diisi.';
  String get formYearError => isEnglish
      ? 'Enter a valid vehicle year.'
      : 'Masukkan tahun kendaraan yang valid.';
  String get formMileageError => isEnglish
      ? 'Mileage must be a number of at least 0.'
      : 'Jarak tempuh harus berupa angka minimal 0.';
  String get formFuelError => isEnglish
      ? 'Fuel level must be between 0 and 100.'
      : 'Level bahan bakar harus antara 0 dan 100.';

  // ==========================================
  // SERVICE HISTORY & BLOCKCHAIN
  // ==========================================
  String get serviceHistoryTitle =>
      isEnglish ? 'Service History' : 'Riwayat Servis';
  String get serviceHistory => serviceHistoryTitle;
  String get blockchainValid =>
      isEnglish ? 'Blockchain Valid' : 'Blockchain Valid';
  String get blockchainBroken =>
      isEnglish ? 'Integrity Broken' : 'Integritas Rusak';
  String get addServiceRecordTooltip =>
      isEnglish ? 'Add Service Record' : 'Tambah Catatan Servis';
  String get addServiceRecordDialogTitle => isEnglish
      ? 'Add Service Record (Blockchain)'
      : 'Tambah Catatan Servis (Blockchain)';
  String get serviceNameLabel =>
      isEnglish ? 'Service / Job Name' : 'Nama Servis / Pekerjaan';
  String get serviceNameHint =>
      isEnglish ? 'e.g. Engine Oil Change' : 'Contoh: Ganti Oli Mesin';
  String get serviceCategoryLabel => isEnglish ? 'Category' : 'Kategori';
  String get workshopLabel => isEnglish ? 'Workshop' : 'Bengkel';
  String get vehicleMileageKmLabel =>
      isEnglish ? 'Vehicle Mileage (km)' : 'Kilometer Kendaraan (km)';
  String get serviceCostLabel => isEnglish ? 'Cost' : 'Biaya';
  String get additionalNotesLabel =>
      isEnglish ? 'Additional Notes' : 'Catatan Tambahan';
  String get additionalNotesHint => isEnglish
      ? 'e.g. Fully Synthetic 0W-20 oil & new oil filter'
      : 'Contoh: Oli Fully Synthetic 0W-20 & filter oli baru';
  String get saveAndHashBlockBtn =>
      isEnglish ? 'Save & Hash Block' : 'Simpan & Hash Blok';
  String get serviceRecordSavedSuccess => isEnglish
      ? 'Service record successfully saved to database & blockchain.'
      : 'Catatan servis berhasil ditambahkan ke database & blockchain.';
  String get serviceNameRequiredError =>
      isEnglish ? 'Service name is required.' : 'Nama servis wajib diisi.';
  String get noVehicleSelectedNotice => isEnglish
      ? 'No vehicle selected yet. Please add a vehicle first in the Vehicles tab.'
      : 'Belum ada kendaraan yang dipilih. Silakan tambahkan kendaraan terlebih dahulu di menu Kendaraan.';
  String get noServiceHistoryTitle =>
      isEnglish ? 'No Service History Yet' : 'Belum Ada Riwayat Servis';
  String get noServiceHistoryDesc => isEnglish
      ? 'Service records you add will be encrypted into the digital blockchain here.'
      : 'Catatan servis yang Anda tambahkan akan dienkripsi ke dalam blockchain digital di sini.';
  String get vehiclePrefix => isEnglish ? 'Vehicle' : 'Kendaraan';
  String get addVehicleInMenuHint => isEnglish
      ? 'Add a vehicle in the Vehicles menu'
      : 'Tambahkan kendaraan di menu Kendaraan';
  String get costEstimationTitle =>
      isEnglish ? 'Maintenance Cost Estimation' : 'Estimasi Biaya Perawatan';
  String get costEstimation => costEstimationTitle;
  String get nextPeriodicService =>
      isEnglish ? 'Next Periodic Service' : 'Servis Berkala Berikutnya';
  String get oilChangeEstimation =>
      isEnglish ? 'Estimated Oil Change' : 'Estimasi Ganti Oli';
  String get annualTax =>
      isEnglish ? 'Annual Vehicle Tax' : 'Pajak Tahunan PKB';
  String get yearServiceExpense =>
      isEnglish ? 'This Year Service Expense' : 'Pengeluaran Servis Tahun Ini';

  // ==========================================
  // NOTIFICATIONS & REMINDERS
  // ==========================================
  String get notificationsTitle =>
      isEnglish ? 'Notifications & Reminders' : 'Notifikasi & Pengingat';
  String get addReminderTooltip =>
      isEnglish ? 'Schedule New Reminder' : 'Atur Pengingat Baru';
  String get editReminderTitle =>
      isEnglish ? 'Edit Service Reminder' : 'Ubah Pengingat Servis';
  String get scheduleReminderTitle =>
      isEnglish ? 'Schedule Service Reminder' : 'Atur Pengingat Servis';
  String get reminderTitleLabel =>
      isEnglish ? 'Reminder Title' : 'Judul Pengingat';
  String get reminderTitleHint =>
      isEnglish ? 'e.g. Engine Oil Change' : 'Contoh: Ganti Oli Mesin';
  String get reminderCategoryLabel => isEnglish ? 'Category' : 'Kategori';
  String get reminderMessageLabel =>
      isEnglish ? 'Message / Description' : 'Pesan / Deskripsi';
  String get reminderMessageHint =>
      isEnglish ? 'Reminder description...' : 'Deskripsi pengingat...';
  String get targetDateLabel =>
      isEnglish ? 'Target Date & Time' : 'Tanggal & Waktu Target';
  String get saveReminderBtn =>
      isEnglish ? 'Save Reminder' : 'Simpan Pengingat';
  String get deleteReminderTitle =>
      isEnglish ? 'Delete Reminder' : 'Hapus Pengingat';
  String get deleteReminderConfirm => isEnglish
      ? 'Are you sure you want to delete this reminder?'
      : 'Apakah Anda yakin ingin menghapus pengingat ini?';
  String get reminderSavedSuccess => isEnglish
      ? 'Reminder saved successfully.'
      : 'Pengingat berhasil disimpan.';
  String get reminderDeletedSuccess => isEnglish
      ? 'Reminder deleted successfully.'
      : 'Pengingat berhasil dihapus.';
  String get noNotificationsTitle =>
      isEnglish ? 'No Notifications' : 'Tidak Ada Notifikasi';
  String get noNotificationsDesc => isEnglish
      ? 'All vehicle schedules are on track and there are no active reminders.'
      : 'Semua jadwal kendaraan Anda terpantau aman dan belum ada pengingat baru.';
  String get notifPermissionBannerTitle => isEnglish
      ? 'Notification Permission Needed'
      : 'Izin Notifikasi Diperlukan';
  String get notifPermissionBannerMsg => isEnglish
      ? 'Allow notification permission so DriveMate can alert you when service and tax schedules are due.'
      : 'Aktifkan izin notifikasi agar DriveMate dapat mengingatkan Anda saat jadwal servis & pajak tiba.';
  String get grantPermissionBtn =>
      isEnglish ? 'Grant Permission' : 'Beri Izin';
  String get reminderTitleRequired => isEnglish
      ? 'Reminder title is required.'
      : 'Judul pengingat wajib diisi.';

  // ==========================================
  // TRIPS & SENSORS
  // ==========================================
  String get tripsTitle => isEnglish ? 'Trips' : 'Perjalanan';
  String get searchLocationHint => isEnglish
      ? 'Search location, gas station, or workshop...'
      : 'Cari lokasi, SPBU, atau bengkel...';
  String get selectDestination =>
      isEnglish ? 'Select destination' : 'Pilih tempat tujuan';
  String get startNavigation =>
      isEnglish ? 'Start Navigation' : 'Mulai Navigasi';
  String get stopNavigation =>
      isEnglish ? 'Stop Navigation' : 'Selesai Navigasi';
  String get distanceLabel => isEnglish ? 'Distance' : 'Jarak';
  String get estimatedDuration =>
      isEnglish ? 'Estimated Time' : 'Estimasi Waktu';
  String get minutesUnit => isEnglish ? 'mins' : 'menit';
  String get nearbyGasStations =>
      isEnglish ? 'Nearby Gas Stations' : 'SPBU Terdekat';
  String get nearbyWorkshops =>
      isEnglish ? 'Nearby Workshops' : 'Bengkel Terdekat';
  String get compassHeading => isEnglish ? 'Compass' : 'Kompas';
  String get speedKmh => isEnglish ? 'Speed' : 'Kecepatan';
  String get altitudeMeter => isEnglish ? 'Altitude' : 'Ketinggian';
  String get savedTrips =>
      isEnglish ? 'Saved Trips' : 'Riwayat Rute Tersimpan';
  String get noSavedTrips => isEnglish
      ? 'No saved trip routes yet.'
      : 'Belum ada rute perjalanan yang tersimpan.';
  String get gpsSignalWaiting => isEnglish
      ? 'GPS signal is not locked yet. Make sure you are in an open area and GPS is active.'
      : 'Sinyal GPS belum terkunci. Pastikan Anda berada di area terbuka dan GPS aktif.';
  String get gpsDisabled => isEnglish
      ? 'GPS service is disabled.'
      : 'Layanan GPS dinonaktifkan.';
  String get enableGps => isEnglish ? 'Enable GPS' : 'Aktifkan GPS';
  String get openSettings => isEnglish ? 'Open Settings' : 'Buka Pengaturan';
  String get sensorPanelTitle =>
      isEnglish ? 'Live Driving Sensors' : 'Sensor Real-Time';
  String get tripHistoryTitle =>
      isEnglish ? 'Trip History' : 'Riwayat Rute Perjalanan';
  String get searchPlaceTitle =>
      isEnglish ? 'Search Places' : 'Pencarian Tempat';
  String get searchResultsTitle =>
      isEnglish ? 'Search Results' : 'Hasil Pencarian';
  String get noSearchResults => isEnglish
      ? 'No places found matching your search.'
      : 'Tidak ada tempat yang sesuai dengan pencarian.';

  // ==========================================
  // AI ASSISTANT
  // ==========================================
  String get aiTitle => 'AI Vehicle Assistant';
  String get aiSubtitle => isEnglish
      ? 'Analyzing maintenance, damage symptoms, & routes'
      : 'Menganalisis perawatan, gejala kerusakan, & rute';
  String get aiGreeting => isEnglish
      ? 'Hello! I am DriveMate smart automotive assistant. How can I help you regarding vehicle condition, service schedules, or maintenance tips?'
      : 'Halo! Saya asisten pintar otomotif DriveMate. Ada yang bisa saya bantu terkait kondisi kendaraan, jadwal servis, atau tips perawatan mobil & motor Anda?';
  String get aiInputHint => isEnglish
      ? 'Ask about vehicle issues or maintenance...'
      : 'Tanyakan kendala atau perawatan kendaraan...';
  String get aiThinking => isEnglish
      ? 'AI is processing response...'
      : 'AI sedang memproses jawaban...';
  String get aiResetTooltip =>
      isEnglish ? 'Reset Conversation' : 'Reset Percakapan';
  String get aiResetNotice => isEnglish
      ? 'Conversation has been reset. Please ask anything new about your vehicle.'
      : 'Percakapan telah direset. Silakan tanyakan hal baru seputar kendaraan Anda.';
  String get aiErrorPrefix => isEnglish
      ? 'Failed to process AI response'
      : 'Gagal memproses respon AI';

  // ==========================================
  // PROFILE PAGE
  // ==========================================
  String get profileTitle => isEnglish ? 'Profile' : 'Profil';
  String get editProfile => isEnglish ? 'Edit Profile' : 'Edit Profil';
  String get profileUpdatedSuccess => isEnglish
      ? 'Profile updated successfully.'
      : 'Profil berhasil diperbarui.';
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

  // ==========================================
  // SETTINGS PAGE & PREFERENCES
  // ==========================================
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
  String get selectLanguage => isEnglish ? 'Select Language' : 'Pilih Bahasa';
  String get currency => isEnglish ? 'Currency' : 'Mata Uang';
  String get currencySubtitle => isEnglish
      ? 'Select the app primary display currency'
      : 'Pilih mata uang utama tampilan aplikasi';
  String get selectCurrency => isEnglish ? 'Select Currency' : 'Pilih Mata Uang';
  String get timeZone => isEnglish ? 'Time Zone' : 'Zona Waktu';
  String get timeZoneSubtitle => isEnglish
      ? 'Select display time zone for schedules and activities'
      : 'Pilih zona waktu tampilan jadwal dan riwayat';
  String get selectTimeZone =>
      isEnglish ? 'Select Time Zone' : 'Pilih Zona Waktu';
  String get distanceUnit => isEnglish ? 'Distance Unit' : 'Satuan Jarak';
  String get sectionSecurity =>
      isEnglish ? 'Security & Authentication' : 'Keamanan & Autentikasi';
  String get biometricLockTitle => isEnglish
      ? 'Biometric Lock (Fingerprint / Face)'
      : 'Kunci Biometrik (Sidik Jari / Wajah)';
  String get biometricLockSub => isEnglish
      ? 'Require biometric unlock when returning to the app'
      : 'Minta autentikasi biometrik saat kembali ke aplikasi';
  String get pinLockTitle =>
      isEnglish ? 'Alternative PIN Lock' : 'Kunci PIN Alternatif';
  String get pinLockSub => isEnglish
      ? 'Set and use a 6-digit PIN as a security lock'
      : 'Atur dan gunakan PIN 6 digit sebagai pengaman';
  String get pinSetButton => isEnglish ? 'Configure PIN' : 'Atur PIN (6 Digit)';
  String get pinChangeButton => isEnglish ? 'Change PIN' : 'Ubah PIN';
  String get pinDisableButton =>
      isEnglish ? 'Disable PIN' : 'Nonaktifkan PIN';
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

  // ==========================================
  // SECURITY & PIN LOCK SCREEN
  // ==========================================
  String get appLockedTitle =>
      isEnglish ? 'App Locked' : 'Aplikasi Terkunci';
  String get unlockWithBiometric =>
      isEnglish ? 'Unlock with Biometrics' : 'Buka dengan Biometrik';
  String get unlockWithPin =>
      isEnglish ? 'Unlock with PIN' : 'Buka dengan PIN';
  String get enterPinToUnlock => isEnglish
      ? 'Enter your 6-digit PIN to continue'
      : 'Masukkan PIN 6 digit untuk melanjutkan';
  String get createPinDialogTitle =>
      isEnglish ? 'Create 6-Digit PIN' : 'Buat PIN 6 Digit';
  String get confirmPinDialogTitle =>
      isEnglish ? 'Confirm 6-Digit PIN' : 'Konfirmasi PIN 6 Digit';
  String get enterCurrentPinTitle =>
      isEnglish ? 'Enter Current PIN' : 'Masukkan PIN Saat Ini';
  String get enterNewPinTitle =>
      isEnglish ? 'Enter New 6-Digit PIN' : 'Masukkan PIN Baru (6 Digit)';
  String get pinMustBe6Digits => isEnglish
      ? 'PIN must be at least 6 digits.'
      : 'PIN harus berupa minimal 6 digit angka.';
  String get pinMismatch => isEnglish
      ? 'PIN confirmation does not match.'
      : 'Konfirmasi PIN tidak cocok.';
  String get pinCreatedSuccess => isEnglish
      ? 'Security PIN successfully created.'
      : 'PIN keamanan berhasil dibuat.';
  String get pinChangedSuccess => isEnglish
      ? 'Security PIN successfully changed.'
      : 'PIN keamanan berhasil diubah.';
  String get pinDisabledSuccess => isEnglish
      ? 'Security PIN disabled.'
      : 'Kunci PIN berhasil dinonaktifkan.';
  String get pinIncorrect =>
      isEnglish ? 'Incorrect PIN. Attempts left:' : 'PIN salah. Sisa percobaan:';
  String get pinLockoutNotice => isEnglish
      ? 'Too many failed attempts. Please wait'
      : 'Terlalu banyak percobaan salah. Mohon tunggu';
  String get secondsSuffix => isEnglish ? 'seconds' : 'detik';
  String get biometricNotEnrolledMsg => isEnglish
      ? 'Biometrics not available or not enrolled on this device.'
      : 'Sensor biometrik tidak tersedia atau belum didaftarkan di perangkat.';
  String get biometricPromptReason => isEnglish
      ? 'Please scan fingerprint or face to authenticate'
      : 'Pindai sidik jari atau wajah Anda untuk masuk ke DriveMate';
  String get switchAuthMethod => isEnglish
      ? 'Switch to PIN / Biometrics'
      : 'Ganti ke PIN / Biometrik';

  // ==========================================
  // ACTIVITY HISTORY PAGE
  // ==========================================
  String get activityHistoryTitle =>
      isEnglish ? 'Activity History' : 'Riwayat Aktivitas';
  String get filterAll => isEnglish ? 'All' : 'Semua';
  String get filterVehicles => isEnglish ? 'Vehicles' : 'Kendaraan';
  String get filterServices => isEnglish ? 'Services' : 'Servis';
  String get filterTrips => isEnglish ? 'Trips' : 'Perjalanan';
  String get filterReminders => isEnglish ? 'Reminders' : 'Pengingat';
  String get noActivityTitle =>
      isEnglish ? 'No Activity History Yet' : 'Belum Ada Riwayat Aktivitas';
  String get noActivityDesc => isEnglish
      ? 'Activities such as vehicle additions, services, and trips will be tracked here.'
      : 'Aktivitas seperti penambahan kendaraan, servis berkala, dan rute perjalanan akan tercatat secara nyata di sini.';

  // ==========================================
  // FEEDBACK PAGE
  // ==========================================
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

  // ==========================================
  // MINI-GAME
  // ==========================================
  String get gameScoreLabel => isEnglish ? 'Score' : 'Skor';
  String get gameLevelLabel => isEnglish ? 'Level' : 'Level';
  String get gameLivesLabel => isEnglish ? 'Lives' : 'Nyawa';
  String get gameTapToJump =>
      isEnglish ? 'Tap to jump' : 'Tap untuk melompat';
  String get gameOverTitle => 'Game Over!';
  String gameFinalScore(int score) =>
      isEnglish ? 'Final Score: $score pts' : 'Skor Akhir: $score poin';
  String get playAgainBtn => isEnglish ? 'Play Again' : 'Main Lagi';

  // ==========================================
  // LOGIN, REGISTER & SPLASH
  // ==========================================
  String get loginHeading =>
      isEnglish ? 'Sign In to Your Account' : 'Masuk ke Akun Anda';
  String get loginSubheading => isEnglish
      ? 'Manage all your vehicles in one smart app'
      : 'Kelola seluruh kendaraan Anda dalam satu aplikasi pintar';
  String get identifierHint =>
      isEnglish ? 'Email or Phone Number' : 'Email atau Nomor HP';
  String get passwordLabel => isEnglish ? 'Password' : 'Password';
  String get rememberMe => isEnglish ? 'Remember me' : 'Ingat saya';
  String get forgotPassword =>
      isEnglish ? 'Forgot password?' : 'Lupa password?';
  String get loginBtn => isEnglish ? 'Sign In' : 'Login';
  String get orSignInWith =>
      isEnglish ? 'or sign in with' : 'atau masuk dengan';
  String get noAccountYet =>
      isEnglish ? "Don't have an account? " : 'Belum punya akun? ';
  String get registerLink => isEnglish ? 'Sign Up' : 'Daftar';
  String get loginFailedMsg => isEnglish
      ? 'Email/Phone or password incorrect. Try: andi@email.com / 123456'
      : 'Email/No. HP atau password salah. Coba: andi@email.com / 123456';
  String get biometricAuthFailedMsg => isEnglish
      ? 'Biometric authentication was unsuccessful or canceled.'
      : 'Autentikasi biometrik tidak berhasil atau dibatalkan.';
  String get registerHeading =>
      isEnglish ? 'Create New Account' : 'Buat Akun Baru';
  String get registerSubheading => isEnglish
      ? 'Start your smart journey with DriveMate'
      : 'Mulai perjalanan pintar bersama DriveMate';
  String get phoneHint =>
      isEnglish ? 'WhatsApp / Phone Number' : 'Nomor WhatsApp / HP';
  String get confirmPasswordLabel =>
      isEnglish ? 'Confirm Password' : 'Konfirmasi Password';
  String get confirmPasswordHint =>
      isEnglish ? 'Repeat your password' : 'Ulangi password Anda';
  String get registerBtn => isEnglish ? 'Create Account' : 'Daftar Sekarang';
  String get alreadyHaveAccount =>
      isEnglish ? 'Already have an account? ' : 'Sudah punya akun? ';
  String get splashTagline => isEnglish
      ? 'Personal assistant for\nyour vehicles'
      : 'Asisten pribadi untuk\nkendaraan Anda';
  String get getStartedBtn => isEnglish ? 'Get Started' : 'Mulai Sekarang';

  // ==========================================
  // DYNAMIC DATA TRANSLATION HELPERS
  // (Translates seeded/system strings without touching DB)
  // ==========================================

  /// Translates reminder category names
  String translateCategory(String category) {
    if (!isEnglish) return category;
    final catLower = category.trim().toLowerCase();
    switch (catLower) {
      case 'semua':
        return 'All';
      case 'servis':
        return 'Service';
      case 'pajak':
        return 'Tax';
      case 'perawatan':
        return 'Maintenance';
      case 'sistem':
        return 'System';
      case 'penggantian':
        return 'Replacement';
      case 'pemeriksaan':
        return 'Inspection';
      case 'lainnya':
        return 'Other';
      default:
        return category;
    }
  }

  /// Translates seeded & system reminder titles
  String translateReminderTitle(String title) {
    if (!isEnglish) return title;
    final t = title.trim();
    final lower = t.toLowerCase();

    if (lower == 'pengingat servis') return 'Service Reminder';
    if (lower == 'pajak kendaraan') return 'Vehicle Tax';
    if (lower == 'cuaca buruk') return 'Severe Weather';
    if (lower == 'pembaruan aplikasi') return 'App Update';
    if (lower == 'cek aki & ban') return 'Battery & Tire Inspection';
    if (lower == 'perawatan kampas rem') return 'Brake Pad Maintenance';
    if (lower == 'ganti oli mesin') return 'Engine Oil Change';
    if (lower == 'servis berkala') return 'Periodic Service';
    if (lower == 'servis rutin') return 'Routine Service';
    if (lower == 'pajak tahunan' || lower == 'pajak tahunan stnk' || lower == 'pajak stnk') {
      return 'Annual Vehicle Tax';
    }

    // If title has user custom text, preserve it
    return t;
  }

  /// Translates reminder messages (template & seed strings) without modifying DB
  String translateReminderMessage(String message, {String? category}) {
    if (!isEnglish) return message;
    final msg = message.trim();

    // 1. Check exact seed matches & common variations
    if (msg == 'Servis berkala sudah mendekati. Dalam 2.500 km lagi.' ||
        msg == 'Jadwal servis berkala sudah dekat. Dalam 2.500 km.') {
      return 'Periodic service is due soon. Within 2,500 km.';
    }
    if (msg == 'Pajak kendaraan Anda akan jatuh tempo pada 12 Jul 2026.') {
      return 'Your vehicle tax will be due on 12 Jul 2026.';
    }
    if (msg == 'Masa berlaku STNK habis dalam 30 hari.') {
      return 'Vehicle registration expires in 30 days.';
    }
    if (msg == 'Diperkirakan hujan di lokasi Anda pada 1 jam ke depan.') {
      return 'Rain is forecasted at your location within the next 1 hour.';
    }
    if (msg == 'Versi terbaru tersedia. Fitur lebih lengkap dan stabil.') {
      return 'Latest version available. More complete features and stable.';
    }

    // 2. Pattern: "Jadwal <category> kendaraan Anda telah tiba. Silakan lakukan perawatan berkala."
    final scheduleRegex = RegExp(
      r'Jadwal\s+(.*?)\s+kendaraan Anda telah tiba\.\s*Silakan lakukan perawatan berkala\.',
      caseSensitive: false,
    );
    final match = scheduleRegex.firstMatch(msg);
    if (match != null) {
      final matchedCat = match.group(1) ?? category ?? 'maintenance';
      final translatedCat = translateCategory(matchedCat);
      return 'Your vehicle $translatedCat schedule has arrived. Please perform periodic maintenance.';
    }

    // Return original message for custom user-created input
    return msg;
  }

  /// Translates relative time expressions like "2 jam lalu" -> "2 hours ago"
  String translateTimeAgo(String timeAgo) {
    if (!isEnglish) return timeAgo;
    final trimmed = timeAgo.trim();
    final lower = trimmed.toLowerCase();

    if (lower == 'dijadwalkan') return 'Scheduled';
    if (lower == 'diperbarui') return 'Updated';
    if (lower == 'baru saja') return 'Just now';

    final regex = RegExp(r'^(\d+)\s*(jam|hari|menit|detik|bulan|tahun)\s*lalu$');
    final m = regex.firstMatch(lower);
    if (m != null) {
      final num = m.group(1);
      final unit = m.group(2);
      final isPlural = (int.tryParse(num ?? '1') ?? 1) > 1;
      String enUnit = 'hour';
      switch (unit) {
        case 'jam':
          enUnit = isPlural ? 'hours' : 'hour';
          break;
        case 'hari':
          enUnit = isPlural ? 'days' : 'day';
          break;
        case 'menit':
          enUnit = isPlural ? 'mins' : 'min';
          break;
        case 'detik':
          enUnit = isPlural ? 'secs' : 'sec';
          break;
        case 'bulan':
          enUnit = isPlural ? 'months' : 'month';
          break;
        case 'tahun':
          enUnit = isPlural ? 'years' : 'year';
          break;
      }
      return '$num $enUnit ago';
    }

    return trimmed;
  }

  /// Translates vehicle status: 'Aktif' -> 'Active'
  String translateVehicleStatus(String status) {
    if (!isEnglish) return status;
    final lower = status.trim().toLowerCase();
    switch (lower) {
      case 'aktif':
        return 'Active';
      case 'nonaktif':
        return 'Inactive';
      case 'dalam servis':
        return 'In Service';
      case 'kondisi baik':
        return 'Good Condition';
      case 'perlu servis':
        return 'Service Due';
      default:
        return status;
    }
  }

  /// Translates activity history items
  String translateActivityTitle(String title) {
    if (!isEnglish) return title;
    if (title == 'Kendaraan Terdaftar') return 'Vehicle Registered';
    if (title.startsWith('Servis: ')) {
      return 'Service: ${title.substring(8)}';
    }
    if (title.startsWith('Perjalanan: ')) {
      return 'Trip: ${title.substring(12)}';
    }
    if (title.startsWith('Pengingat: ')) {
      return 'Reminder: ${translateReminderTitle(title.substring(11))}';
    }
    return title;
  }
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
