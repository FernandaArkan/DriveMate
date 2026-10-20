import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/vehicle.dart';

class VehicleRepository extends ChangeNotifier {
  VehicleRepository._internal();
  static final VehicleRepository instance = VehicleRepository._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Vehicle> _vehicles = [];
  Vehicle? _primaryVehicle;
  bool _isLoading = false;

  List<Vehicle> get vehicles => _vehicles;
  Vehicle? get primaryVehicle => _primaryVehicle;
  bool get isLoading => _isLoading;

  Future<void> loadVehicles() async {
    _isLoading = true;
    notifyListeners();

    try {
      _vehicles = await _dbHelper.getVehicles();
      _primaryVehicle = await _dbHelper.getPrimaryVehicle();
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addVehicle(Vehicle vehicle) async {
    try {
      final id = await _dbHelper.insertVehicle(vehicle);
      if (id > 0) {
        await loadVehicles();
        return true;
      }
    } catch (e) {
      debugPrint('Error adding vehicle: $e');
    }
    return false;
  }

  Future<bool> updateVehicle(Vehicle vehicle) async {
    try {
      final rows = await _dbHelper.updateVehicle(vehicle);
      if (rows > 0) {
        await loadVehicles();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating vehicle: $e');
    }
    return false;
  }

  Future<bool> deleteVehicle(int id) async {
    try {
      final rows = await _dbHelper.deleteVehicle(id);
      if (rows > 0) {
        await loadVehicles();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting vehicle: $e');
    }
    return false;
  }

  Future<void> setPrimaryVehicle(int id) async {
    try {
      await _dbHelper.setPrimaryVehicle(id);
      await loadVehicles();
    } catch (e) {
      debugPrint('Error setting primary vehicle: $e');
    }
  }
}
