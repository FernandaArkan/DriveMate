
class Vehicle {
  Vehicle({
    this.id,
    this.serverId,
    required this.name,
    required this.brand,
    required this.year,
    required this.plate,
    required this.mileage,
    this.fuelLevel = 65,
    this.status = 'Aktif',
    this.isPrimary = false,
    this.lastServiceDate,
    this.taxDueDate,
    this.createdAt,
    this.isSynced = 1,
  });

  final int? id;
  final int? serverId;
  String name;
  String brand;
  int year;
  String plate;
  int mileage;
  int fuelLevel;
  String status;
  bool isPrimary;
  String? lastServiceDate;
  String? taxDueDate;
  String? createdAt;
  int isSynced;

  // Format data untuk SQLite.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'serverId': serverId,
      'name': name,
      'brand': brand,
      'year': year,
      'plate': plate,
      'mileage': mileage,
      'fuelLevel': fuelLevel,
      'status': status,
      'isPrimary': isPrimary ? 1 : 0,
      'lastServiceDate': lastServiceDate,
      'taxDueDate': taxDueDate,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
      'isSynced': isSynced,
    };
  }

  // Format data untuk API PostgreSQL.
  Map<String, dynamic> toApiMap({required int userId}) {
    return {
      'user_id': userId,
      'name': name,
      'brand': brand,
      'model': name,
      'plate': plate,
      'year': year,
      'mileage': mileage,
      'fuelLevel': fuelLevel,
      'status': status,
      'isPrimary': isPrimary,
      'lastServiceDate': _toApiDate(lastServiceDate),
      'taxDueDate': _toApiDate(taxDueDate),
    };
  }

  // Mengubah tanggal tampilan menjadi format YYYY-MM-DD.
  String? _toApiDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      final month = parsed.month.toString().padLeft(2, '0');
      final day = parsed.day.toString().padLeft(2, '0');

      return '${parsed.year}-$month-$day';
    }

    // Tanggal dengan format seperti "05 Jan 2025"
    // belum dikonversi otomatis di sini.
    return value;
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    int toInt(dynamic value, int fallback) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? fallback;
    }

    bool toBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;

      final text = value?.toString().toLowerCase();
      return text == 'true' || text == '1';
    }

    return Vehicle(
      id: map['id'] == null ? null : toInt(map['id'], 0),
      serverId: map['serverId'] == null ? null : toInt(map['serverId'], 0),
      name: map['name']?.toString() ?? '',
      brand: map['brand']?.toString() ?? '',
      year: toInt(map['year'], DateTime.now().year),
      plate: (map['plate'] ?? map['plate_number'])?.toString() ?? '',
      mileage: toInt(map['mileage'], 0),
      fuelLevel: toInt(map['fuelLevel'] ?? map['fuel_level'], 65),
      status: map['status']?.toString() ?? 'Aktif',
      isPrimary: toBool(map['isPrimary'] ?? map['is_primary']),
      lastServiceDate:
          (map['lastServiceDate'] ?? map['last_service_date'])?.toString(),
      taxDueDate:
          (map['taxDueDate'] ?? map['tax_due_date'])?.toString(),
      createdAt:
          (map['createdAt'] ?? map['created_at'])?.toString(),
      isSynced: toInt(map['isSynced'] ?? map['is_synced'], 1),
    );
  }

  Vehicle copyWith({
    int? id,
    String? name,
    String? brand,
    int? year,
    String? plate,
    int? mileage,
    int? fuelLevel,
    String? status,
    bool? isPrimary,
    String? lastServiceDate,
    String? taxDueDate,
    String? createdAt,
    int? isSynced,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      year: year ?? this.year,
      plate: plate ?? this.plate,
      mileage: mileage ?? this.mileage,
      fuelLevel: fuelLevel ?? this.fuelLevel,
      status: status ?? this.status,
      isPrimary: isPrimary ?? this.isPrimary,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      taxDueDate: taxDueDate ?? this.taxDueDate,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
