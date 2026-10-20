import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../theme/app_theme.dart';

class VehicleFormDialog extends StatefulWidget {
  const VehicleFormDialog({
    super.key,
    this.vehicle,
  });

  final Vehicle? vehicle;

  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _yearController;
  late final TextEditingController _plateController;
  late final TextEditingController _mileageController;
  late final TextEditingController _fuelController;

  @override
  void initState() {
    super.initState();

    final vehicle = widget.vehicle;

    _nameController = TextEditingController(
      text: vehicle?.name ?? '',
    );
    _brandController = TextEditingController(
      text: vehicle?.brand ?? '',
    );
    _yearController = TextEditingController(
      text: vehicle != null ? vehicle.year.toString() : '',
    );
    _plateController = TextEditingController(
      text: vehicle?.plate ?? '',
    );
    _mileageController = TextEditingController(
      text: vehicle != null ? vehicle.mileage.toString() : '',
    );
    _fuelController = TextEditingController(
      text: vehicle != null ? vehicle.fuelLevel.toString() : '65',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _mileageController.dispose();
    _fuelController.dispose();

    super.dispose();
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label wajib diisi.';
    }

    return null;
  }

  String? _yearValidator(String? value) {
    final requiredError = _requiredValidator(value, 'Tahun kendaraan');

    if (requiredError != null) return requiredError;

    final year = int.tryParse(value!.trim());

    if (year == null ||
        year < 1886 ||
        year > DateTime.now().year + 1) {
      return 'Masukkan tahun kendaraan yang valid.';
    }

    return null;
  }

  String? _mileageValidator(String? value) {
    final requiredError = _requiredValidator(value, 'Jarak tempuh');

    if (requiredError != null) return requiredError;

    final mileage = int.tryParse(value!.trim());

    if (mileage == null || mileage < 0) {
      return 'Jarak tempuh harus berupa angka minimal 0.';
    }

    return null;
  }

  void _saveVehicle() {
    if (!_formKey.currentState!.validate()) return;

    final fuel = int.tryParse(_fuelController.text.trim()) ?? 65;

    final vehicle = Vehicle(
      id: widget.vehicle?.id,
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      year: int.parse(_yearController.text.trim()),
      plate: _plateController.text.trim().toUpperCase(),
      mileage: int.parse(_mileageController.text.trim()),
      fuelLevel: fuel.clamp(0, 100),
      status: widget.vehicle?.status ?? 'Dalam kondisi baik',
      isPrimary: widget.vehicle?.isPrimary ?? false,
      lastServiceDate: widget.vehicle?.lastServiceDate ?? 'Belum ada data',
      taxDueDate: widget.vehicle?.taxDueDate ?? '12 Jul 2026',
    );

    Navigator.of(context).pop(vehicle);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.vehicle != null;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(
        isEditing ? 'Edit Kendaraan' : 'Tambah Kendaraan',
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Nama kendaraan',
                  hint: 'Contoh: Civic',
                  icon: Icons.directions_car_outlined,
                  validator: (value) =>
                      _requiredValidator(value, 'Nama kendaraan'),
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _brandController,
                  label: 'Merek kendaraan',
                  hint: 'Contoh: Honda',
                  icon: Icons.business_outlined,
                  validator: (value) =>
                      _requiredValidator(value, 'Merek kendaraan'),
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _yearController,
                  label: 'Tahun kendaraan',
                  hint: 'Contoh: 2022',
                  icon: Icons.calendar_today_outlined,
                  numberOnly: true,
                  validator: _yearValidator,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _plateController,
                  label: 'Nomor polisi',
                  hint: 'Contoh: B 1234 KZ',
                  icon: Icons.pin_outlined,
                  validator: (value) =>
                      _requiredValidator(value, 'Nomor polisi'),
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _mileageController,
                  label: 'Jarak tempuh (km)',
                  hint: 'Contoh: 12450',
                  icon: Icons.speed_outlined,
                  numberOnly: true,
                  validator: _mileageValidator,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _fuelController,
                  label: 'Perkiraan Bahan Bakar (%)',
                  hint: 'Contoh: 65',
                  icon: Icons.local_gas_station_outlined,
                  numberOnly: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final val = int.tryParse(value.trim());
                    if (val == null || val < 0 || val > 100) {
                      return 'Nilai harus antara 0 - 100%';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Batal',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        FilledButton.icon(
          onPressed: _saveVehicle,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Simpan'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool numberOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: numberOnly
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: AppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppTheme.textSecondary.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppTheme.primary,
            width: 1.4,
          ),
        ),
      ),
      validator: validator,
    );
  }
}
