class TripRecord {
  TripRecord({
    this.id,
    required this.destination,
    required this.distanceKm,
    required this.durationMinutes,
    required this.date,
    this.startLocation = 'Lokasi Anda',
    this.notes = '',
  });

  final int? id;
  final String destination;
  final double distanceKm;
  final int durationMinutes;
  final String date;
  final String startLocation;
  final String notes;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'destination': destination,
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'date': date,
      'startLocation': startLocation,
      'notes': notes,
    };
  }

  factory TripRecord.fromMap(Map<String, dynamic> map) {
    return TripRecord(
      id: map['id'] as int?,
      destination: map['destination'] as String? ?? '',
      distanceKm: (map['distanceKm'] as num? ?? 0.0).toDouble(),
      durationMinutes: map['durationMinutes'] as int? ?? 0,
      date: map['date'] as String? ?? '',
      startLocation: map['startLocation'] as String? ?? 'Lokasi Anda',
      notes: map['notes'] as String? ?? '',
    );
  }
}
