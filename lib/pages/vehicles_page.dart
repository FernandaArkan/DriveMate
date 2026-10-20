
import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../theme/app_theme.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final List<Vehicle> _vehicles = [
    Vehicle(
      name: 'Civic',
      brand: 'Honda',
      year: 2022,
      plate: 'B 1234 XYZ',
      mileage: 12450,
    ),
    Vehicle(
      name: 'NMAX',
      brand: 'Yamaha',
      year: 2023,
      plate: 'AB 5678 CD',
      mileage: 8200,
    ),
  ];

  Future<void> _openForm({Vehicle? vehicle}) async {
    final formKey = GlobalKey<FormState>();

    final nameController =
        TextEditingController(text: vehicle?.name ?? '');
    final brandController =
        TextEditingController(text: vehicle?.brand ?? '');
    final yearController = TextEditingController(
      text: vehicle?.year.toString() ?? '',
    );
    final plateController =
        TextEditingController(text: vehicle?.plate ?? '');
    final mileageController = TextEditingController(
      text: vehicle?.mileage.toString() ?? '',
    );

    final result = await showDialog<Vehicle>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            vehicle == null
                ? 'Tambah Kendaraan'
                : 'Edit Kendaraan',
          ),
          content: SizedBox(
            width: 360,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      controller: nameController,
                      label: 'Nama kendaraan',
                    ),
                    _buildTextField(
                      controller: brandController,
                      label: 'Merek kendaraan',
                    ),
                    _buildTextField(
                      controller: yearController,
                      label: 'Tahun kendaraan',
                      numberOnly: true,
                    ),
                    _buildTextField(
                      controller: plateController,
                      label: 'Nomor polisi',
                    ),
                    _buildTextField(
                      controller: mileageController,
                      label: 'Jarak tempuh (km)',
                      numberOnly: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                final year = int.tryParse(
                  yearController.text.trim(),
                );
                final mileage = int.tryParse(
                  mileageController.text.trim(),
                );

                if (year == null ||
                    year < 1886 ||
                    year > DateTime.now().year + 1) {
                  ScaffoldMessenger.of(dialogContext)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Tahun kendaraan tidak valid.',
                        ),
                      ),
                    );
                  return;
                }

                if (mileage == null || mileage < 0) {
                  ScaffoldMessenger.of(dialogContext)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Jarak tempuh tidak valid.',
                        ),
                      ),
                    );
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  Vehicle(
                    name: nameController.text.trim(),
                    brand: brandController.text.trim(),
                    year: year,
                    plate: plateController.text
                        .trim()
                        .toUpperCase(),
                    mileage: mileage,
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    brandController.dispose();
    yearController.dispose();
    plateController.dispose();
    mileageController.dispose();

    if (!mounted || result == null) return;

    setState(() {
      if (vehicle == null) {
        _vehicles.add(result);
      } else {
        final index = _vehicles.indexOf(vehicle);

        if (index != -1) {
          _vehicles[index] = result;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          vehicle == null
              ? 'Kendaraan berhasil ditambahkan.'
              : 'Kendaraan berhasil diperbarui.',
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool numberOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: numberOnly
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label wajib diisi.';
          }

          if (numberOnly) {
            final number = int.tryParse(value.trim());

            if (number == null) {
              return 'Masukkan angka yang valid.';
            }

            if (number < 0) {
              return 'Angka tidak boleh negatif.';
            }
          }

          return null;
        },
      ),
    );
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Kendaraan'),
          content: Text(
            'Yakin ingin menghapus ${vehicle.brand} '
            '${vehicle.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _vehicles.remove(vehicle);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kendaraan berhasil dihapus.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Kendaraan Saya',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kelola kendaraan dan pantau kondisinya.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Daftar Kendaraan',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tambah'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_vehicles.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 48,
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada kendaraan.',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Tekan Tambah untuk memasukkan kendaraan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._vehicles.map(_vehicleCard),
          ],
        ),
      ),
    );
  }

  Widget _vehicleCard(Vehicle vehicle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE7EDF6),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.brand} ${vehicle.name}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vehicle.year} • ${vehicle.plate}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openForm(vehicle: vehicle);
                  } else if (value == 'delete') {
                    _deleteVehicle(vehicle);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit kendaraan'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus kendaraan'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.speed_rounded,
                color: AppTheme.primary,
                size: 19,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Jarak tempuh',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${vehicle.mileage} km',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
