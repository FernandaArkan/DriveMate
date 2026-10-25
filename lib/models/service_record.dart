import 'dart:convert';
import 'package:crypto/crypto.dart';

class ServiceRecord {
  static const String genesisHash =
      '0000000000000000000000000000000000000000000000000000000000000000';
  static const String legacyGenesisHash =
      '00000000000000000000000000000000';

  ServiceRecord({
    this.id,
    required this.vehicleId,
    required this.title,
    required this.serviceType,
    required this.date,
    required this.mileage,
    required this.workshop,
    this.cost = 0,
    this.notes = '',
    this.status = 'Selesai',
    required this.prevHash,
    String? hash,
    this.timestamp,
  }) : hash = hash ?? calculateHash(
          vehicleId: vehicleId,
          title: title,
          serviceType: serviceType,
          date: date,
          mileage: mileage,
          workshop: workshop,
          cost: cost,
          notes: notes,
          status: status,
          prevHash: prevHash,
          timestamp: timestamp ?? date,
        );

  final int? id;
  final int vehicleId;
  final String title;
  final String serviceType;
  final String date;
  final int mileage;
  final String workshop;
  final int cost;
  final String notes;
  final String status;
  final String prevHash;
  final String hash;
  final String? timestamp;

  static String calculateHash({
    required int vehicleId,
    required String title,
    required String serviceType,
    required String date,
    required int mileage,
    required String workshop,
    required int cost,
    String notes = '',
    String status = 'Selesai',
    required String prevHash,
    required String timestamp,
  }) {
    final rawData = '$vehicleId|$title|$serviceType|$date|$mileage|$workshop|$cost|$notes|$status|$prevHash|$timestamp';
    final bytes = utf8.encode(rawData);
    return sha256.convert(bytes).toString();
  }

  /// Formula legacy (V1) tanpa notes & status untuk kompatibilitas data lama
  static String calculateLegacyHash({
    required int vehicleId,
    required String title,
    required String serviceType,
    required String date,
    required int mileage,
    required String workshop,
    required int cost,
    required String prevHash,
    required String timestamp,
  }) {
    final rawData = '$vehicleId|$title|$serviceType|$date|$mileage|$workshop|$cost|$prevHash|$timestamp';
    final bytes = utf8.encode(rawData);
    return sha256.convert(bytes).toString();
  }

  bool verifyHash() {
    // 1. Verifikasi dengan formula terbaru (melindungi notes dan status)
    final expectedHash = calculateHash(
      vehicleId: vehicleId,
      title: title,
      serviceType: serviceType,
      date: date,
      mileage: mileage,
      workshop: workshop,
      cost: cost,
      notes: notes,
      status: status,
      prevHash: prevHash,
      timestamp: timestamp ?? date,
    );
    if (hash == expectedHash) return true;

    // 2. Kompatibilitas mundur: verifikasi data lama dengan formula legacy
    final legacyHash = calculateLegacyHash(
      vehicleId: vehicleId,
      title: title,
      serviceType: serviceType,
      date: date,
      mileage: mileage,
      workshop: workshop,
      cost: cost,
      prevHash: prevHash,
      timestamp: timestamp ?? date,
    );
    return hash == legacyHash;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'vehicleId': vehicleId,
      'title': title,
      'serviceType': serviceType,
      'date': date,
      'mileage': mileage,
      'workshop': workshop,
      'cost': cost,
      'notes': notes,
      'status': status,
      'prevHash': prevHash,
      'hash': hash,
      'timestamp': timestamp ?? DateTime.now().toIso8601String(),
    };
  }

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    return ServiceRecord(
      id: map['id'] as int?,
      vehicleId: map['vehicleId'] as int? ?? 1,
      title: map['title'] as String? ?? '',
      serviceType: map['serviceType'] as String? ?? 'Servis',
      date: map['date'] as String? ?? '',
      mileage: map['mileage'] as int? ?? 0,
      workshop: map['workshop'] as String? ?? '',
      cost: map['cost'] as int? ?? 0,
      notes: map['notes'] as String? ?? '',
      status: map['status'] as String? ?? 'Selesai',
      prevHash: map['prevHash'] as String? ?? genesisHash,
      hash: map['hash'] as String?,
      timestamp: map['timestamp'] as String?,
    );
  }
}
