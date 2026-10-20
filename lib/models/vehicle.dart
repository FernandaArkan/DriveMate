class Vehicle {
  Vehicle({
    this.id,
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

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
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

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      year: map['year'] as int? ?? DateTime.now().year,
      plate: map['plate'] as String? ?? '',
      mileage: map['mileage'] as int? ?? 0,
      fuelLevel: map['fuelLevel'] as int? ?? 65,
      status: map['status'] as String? ?? 'Aktif',
      isPrimary: (map['isPrimary'] as int? ?? 0) == 1,
      lastServiceDate: map['lastServiceDate'] as String?,
      taxDueDate: map['taxDueDate'] as String?,
      createdAt: map['createdAt'] as String?,
      isSynced: map['isSynced'] as int? ?? 1,
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
