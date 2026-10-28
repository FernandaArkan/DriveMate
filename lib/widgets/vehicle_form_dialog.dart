import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
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

  String? _requiredValidator(String? value, String label, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.formRequiredError(label);
    }

    return null;
  }

  String? _yearValidator(String? value, AppLocalizations l10n) {
    final requiredError = _requiredValidator(value, l10n.formVehicleYear, l10n);

    if (requiredError != null) return requiredError;

    final year = int.tryParse(value!.trim());

    if (year == null ||
        year < 1886 ||
        year > DateTime.now().year + 1) {
      return l10n.formYearError;
    }

    return null;
  }

  String? _mileageValidator(String? value, AppLocalizations l10n) {
    final requiredError = _requiredValidator(value, l10n.formVehicleMileage, l10n);

    if (requiredError != null) return requiredError;

    final mileage = int.tryParse(value!.trim());

    if (mileage == null || mileage < 0) {
      return l10n.formMileageError;
    }

    return null;
  }

  String? _fuelValidator(String? value, AppLocalizations l10n) {
    final requiredError = _requiredValidator(value, l10n.formVehicleFuel, l10n);

    if (requiredError != null) return requiredError;

    final fuel = int.tryParse(value!.trim());

    if (fuel == null || fuel < 0 || fuel > 100) {
      return l10n.formFuelError;
    }

    return null;
  }

  void _submit() {
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
      status: widget.vehicle?.status ?? 'Aktif',
      isPrimary: widget.vehicle?.isPrimary ?? false,
      lastServiceDate: widget.vehicle?.lastServiceDate,
      taxDueDate: widget.vehicle?.taxDueDate,
      createdAt: widget.vehicle?.createdAt,
      isSynced: widget.vehicle?.isSynced ?? 1,
    );

    Navigator.pop(context, vehicle);
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E9F3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E9F3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.vehicle != null;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing
                              ? Icons.edit_rounded
                              : Icons.add_circle_outline_rounded,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          isEditing
                              ? l10n.dialogEditVehicleTitle
                              : l10n.dialogAddVehicleTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration(
                      l10n.formVehicleName,
                      hint: 'Civic RS',
                    ),
                    validator: (v) => _requiredValidator(v, l10n.formVehicleName, l10n),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _brandController,
                    decoration: _inputDecoration(
                      l10n.formVehicleBrand,
                      hint: 'Honda',
                    ),
                    validator: (v) => _requiredValidator(v, l10n.formVehicleBrand, l10n),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _yearController,
                          decoration: _inputDecoration(
                            l10n.formVehicleYear,
                            hint: '2024',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => _yearValidator(v, l10n),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _plateController,
                          decoration: _inputDecoration(
                            l10n.formVehiclePlate,
                            hint: 'B 1234 ABC',
                          ),
                          validator: (v) => _requiredValidator(v, l10n.formVehiclePlate, l10n),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _mileageController,
                          decoration: _inputDecoration(
                            l10n.formVehicleMileage,
                            hint: '12500',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => _mileageValidator(v, l10n),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _fuelController,
                          decoration: _inputDecoration(
                            l10n.formVehicleFuel,
                            hint: '65',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => _fuelValidator(v, l10n),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          l10n.cancel,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _submit,
                        child: Text(
                          isEditing ? l10n.save : l10n.save,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
