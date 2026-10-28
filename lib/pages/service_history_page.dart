import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/blockchain_document.dart';
import '../models/service_record.dart';
import '../models/vehicle.dart';
import '../repositories/user_repository.dart';
import '../repositories/vehicle_repository.dart';
import '../services/blockchain_document_service.dart';
import '../services/currency_service.dart';
import '../theme/app_theme.dart';

class ServiceHistoryPage extends StatefulWidget {
  const ServiceHistoryPage({super.key, this.initialVehicle});

  final Vehicle? initialVehicle;

  @override
  State<ServiceHistoryPage> createState() => _ServiceHistoryPageState();
}

class _ServiceHistoryPageState extends State<ServiceHistoryPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final VehicleRepository _repo = VehicleRepository.instance;
  Vehicle? _selectedVehicle;
  List<ServiceRecord> _records = [];
  bool _isLoading = true;
  String _selectedFilter = 'Semua';
  bool _isChainValid = true;
  final Map<int, BlockchainDocument> _docCache = {};
  final Set<int> _generatingIds = <int>{};

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoUpdated);
    CurrencyService.instance.addListener(_onSettingsUpdated);
    _selectedVehicle = widget.initialVehicle;
    _initData();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoUpdated);
    CurrencyService.instance.removeListener(_onSettingsUpdated);
    super.dispose();
  }

  void _onSettingsUpdated() {
    if (mounted) setState(() {});
  }

  void _onRepoUpdated() {
    if (mounted) {
      _syncVehicle();
      _loadRecords();
    }
  }

  void _syncVehicle() {
    if (_selectedVehicle != null) {
      final matches = _repo.vehicles.where((v) => v.id == _selectedVehicle!.id);
      if (matches.isNotEmpty) {
        _selectedVehicle = matches.first;
        return;
      }
    }
    _selectedVehicle = widget.initialVehicle ??
        _repo.primaryVehicle ??
        (_repo.vehicles.isNotEmpty ? _repo.vehicles.first : null);
  }

  Future<void> _initData() async {
    if (_repo.vehicles.isEmpty) {
      await _repo.loadVehicles();
    }
    _syncVehicle();
    await _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final vehicle = _selectedVehicle;
    if (vehicle == null || vehicle.id == null) {
      if (mounted) {
        setState(() {
          _records = [];
          _isChainValid = true;
          _isLoading = false;
        });
      }
      return;
    }

    final records = await _dbHelper.getServiceRecords(vehicleId: vehicle.id);
    final isChainValid = await _dbHelper.verifyBlockchainIntegrity(vehicleId: vehicle.id);

    if (mounted) {
      setState(() {
        _records = records;
        _isChainValid = isChainValid;
        _isLoading = false;
      });
    }
  }

  List<ServiceRecord> get _filteredRecords {
    if (_selectedFilter == 'Semua') return _records;
    return _records.where((r) => r.serviceType.toLowerCase() == _selectedFilter.toLowerCase()).toList();
  }

  Future<void> _addNewRecord() async {
    final l10n = AppLocalizations.of(context);
    final vehicle = _selectedVehicle;
    if (vehicle == null || vehicle.id == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.noVehicleSelectedNotice),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final titleCtrl = TextEditingController();
    final workshopCtrl = TextEditingController(text: 'AutoCare Bengkel');
    final mileageCtrl = TextEditingController(text: '${vehicle.mileage + 1000}');
    final costCtrl = TextEditingController(text: '500000');
    final notesCtrl = TextEditingController();
    String serviceType = 'Servis';
    String? titleError;

    final added = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.addServiceRecordDialogTitle,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 4),
              Text(
                '${l10n.vehiclePrefix}: ${vehicle.brand} ${vehicle.name} (${vehicle.plate})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.serviceNameLabel,
                    hintText: l10n.serviceNameHint,
                    errorText: titleError,
                  ),
                  onChanged: (_) {
                    if (titleError != null) {
                      setDlgState(() => titleError = null);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: serviceType,
                  decoration: InputDecoration(labelText: l10n.serviceCategoryLabel),
                  items: [
                    DropdownMenuItem(value: 'Servis', child: Text(l10n.translateCategory('Servis'))),
                    DropdownMenuItem(value: 'Penggantian', child: Text(l10n.translateCategory('Penggantian'))),
                    DropdownMenuItem(value: 'Pemeriksaan', child: Text(l10n.translateCategory('Pemeriksaan'))),
                    DropdownMenuItem(value: 'Lainnya', child: Text(l10n.translateCategory('Lainnya'))),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => serviceType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: workshopCtrl,
                  decoration: InputDecoration(labelText: l10n.workshopLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mileageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.vehicleMileageKmLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.serviceCostLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.additionalNotesLabel,
                    hintText: l10n.additionalNotesHint,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                final trimmedTitle = titleCtrl.text.trim();
                if (trimmedTitle.isEmpty) {
                  setDlgState(() {
                    titleError = l10n.serviceNameRequiredError;
                  });
                  return;
                }

                // Ambil block terakhir untuk rantai hash kendaraan ini
                final lastRecords = await _dbHelper.getServiceRecords(vehicleId: vehicle.id);
                final prevHash = lastRecords.isNotEmpty
                    ? lastRecords.first.hash
                    : ServiceRecord.genesisHash;

                final now = DateTime.now();
                final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
                final inputMileage = int.tryParse(mileageCtrl.text.trim());
                final mileage = (inputMileage != null && inputMileage >= 0)
                    ? inputMileage
                    : vehicle.mileage;
                final cost = int.tryParse(costCtrl.text.trim()) ?? 0;

                final newRec = ServiceRecord(
                  vehicleId: vehicle.id!,
                  title: trimmedTitle,
                  serviceType: serviceType,
                  date: dateStr,
                  mileage: mileage,
                  workshop: workshopCtrl.text.trim().isEmpty ? 'Bengkel' : workshopCtrl.text.trim(),
                  cost: cost,
                  notes: notesCtrl.text.trim(),
                  status: 'Selesai',
                  prevHash: prevHash,
                  timestamp: now.toIso8601String(),
                );

                final insertedId = await _dbHelper.addServiceRecord(newRec);
                if (insertedId <= 0) {
                  setDlgState(() {
                    titleError = 'Gagal menyimpan catatan servis ke database.';
                  });
                  return;
                }

                // Update juga mileage kendaraan jika bertambah
                if (mileage > vehicle.mileage) {
                  vehicle.mileage = mileage;
                  vehicle.lastServiceDate = dateStr;
                  await _repo.updateVehicle(vehicle);
                }

                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx, true);
                }
              },
              child: Text(l10n.saveAndHashBlockBtn),
            ),
          ],
        ),
      ),
    );

    if (added == true) {
      await _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.serviceRecordSavedSuccess),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  Future<void> _handleGeneratePdf(ServiceRecord rec) async {
    final recId = rec.id;
    if (recId == null) return;

    if (_docCache.containsKey(recId)) {
      _showCertificateDetailsDialog(_docCache[recId]!, rec);
      return;
    }

    setState(() {
      _generatingIds.add(recId);
    });

    final vehicle = _selectedVehicle;
    final userId = UserRepository.instance.currentUser?.id;

    final response = await BlockchainDocumentService.instance.generatePdfDocument(
      serviceRecordId: recId,
      vehicleId: vehicle?.id,
      userId: userId,
    );

    if (mounted) {
      setState(() {
        _generatingIds.remove(recId);
      });

      if (response.isSuccess && response.data != null) {
        final doc = response.data!;
        setState(() {
          _docCache[recId] = doc;
        });
        _showCertificateDetailsDialog(doc, rec);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Gagal membuat dokumen PDF.'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Ulangi',
                onPressed: () => _handleGeneratePdf(rec),
              ),
            ),
          );
      }
    }
  }

  void _showCertificateDetailsDialog(BlockchainDocument doc, ServiceRecord rec) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_user_rounded, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.certificateDialogTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rec.title,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: doc.isVerified
                      ? AppTheme.success.withValues(alpha: 0.12)
                      : (doc.isFailed
                          ? AppTheme.danger.withValues(alpha: 0.12)
                          : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      doc.isVerified
                          ? Icons.check_circle_rounded
                          : (doc.isFailed ? Icons.error_rounded : Icons.pending_rounded),
                      size: 16,
                      color: doc.isVerified
                          ? AppTheme.success
                          : (doc.isFailed ? AppTheme.danger : const Color(0xFFB45309)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doc.isVerified
                            ? l10n.verifiedStatus
                            : (doc.isFailed ? l10n.failedStatus : l10n.pendingStatus),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: doc.isVerified
                              ? AppTheme.success
                              : (doc.isFailed ? AppTheme.danger : const Color(0xFFB45309)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.documentIdLabel,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        doc.documentId,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: doc.documentId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.copySuccessNotice), duration: const Duration(seconds: 1)),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.documentHashLabel,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        doc.documentHash,
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textPrimary),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: doc.documentHash));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.copySuccessNotice), duration: const Duration(seconds: 1)),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Jaringan:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  Text(doc.networkName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
              if (doc.transactionHash != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tx Hash:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(
                      '${doc.transactionHash!.substring(0, 10)}...',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: const BorderSide(color: AppTheme.primary),
            ),
            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
            label: Text(l10n.verifyBlockchain, style: const TextStyle(fontSize: 12)),
            onPressed: () async {
              final uri = Uri.parse(doc.verificationUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: Text(l10n.viewPdf, style: const TextStyle(fontSize: 12)),
            onPressed: () async {
              final uri = Uri.parse(doc.pdfUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }

  void _openVerificationDialog() {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    bool isChecking = false;
    Map<String, dynamic>? resultData;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            l10n.verifyServiceDocDialogTitle,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    labelText: l10n.documentIdLabel,
                    hintText: l10n.verifyInputHint,
                    errorText: errorText,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste_rounded, size: 18),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          ctrl.text = data!.text!.trim();
                          setDlgState(() => errorText = null);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (isChecking)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                else if (resultData != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resultData!['status_title'] as String? ?? 'Hasil Verifikasi',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resultData!['status_description'] as String? ?? '',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                    icon: const Icon(Icons.public_rounded, size: 16),
                    label: Text(l10n.verifyBlockchain),
                    onPressed: () async {
                      final url = BlockchainDocumentService.instance.getVerificationUrl(ctrl.text.trim());
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.cancel),
            ),
            if (!isChecking)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.navy),
                onPressed: () async {
                  final text = ctrl.text.trim();
                  if (text.isEmpty) {
                    setDlgState(() => errorText = 'ID Dokumen wajib diisi');
                    return;
                  }
                  setDlgState(() {
                    isChecking = true;
                    errorText = null;
                  });

                  final res = await BlockchainDocumentService.instance.verifyDocument(documentId: text);

                  setDlgState(() {
                    isChecking = false;
                    if (res.isSuccess && res.data != null) {
                      resultData = res.data;
                    } else {
                      errorText = res.message ?? l10n.documentNotFoundNotice;
                    }
                  });
                },
                child: Text(l10n.checkIntegrityBtn),
              ),
          ],
        ),
      ),
    );
  }

  String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehicle = _selectedVehicle;
    final allVehicles = _repo.vehicles;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          l10n.serviceHistoryTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.verifyServiceDocDialogTitle,
            icon: const Icon(Icons.verified_outlined, color: AppTheme.navy),
            onPressed: _openVerificationDialog,
          ),
          IconButton(
            tooltip: l10n.addServiceRecordTooltip,
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
            onPressed: _addNewRecord,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Vehicle Header Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5EDF7)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_car_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle != null
                              ? '${vehicle.brand} ${vehicle.name} ${vehicle.year}'
                              : l10n.noVehicleTitle,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vehicle?.plate ?? l10n.addVehicleInMenuHint,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (vehicle != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isChainValid
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isChainValid ? Icons.verified_rounded : Icons.warning_rounded,
                            size: 14,
                            color: _isChainValid ? AppTheme.success : AppTheme.danger,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isChainValid ? l10n.blockchainValid : l10n.blockchainBroken,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _isChainValid ? AppTheme.success : AppTheme.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            if (allVehicles.length > 1) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: allVehicles.map((v) {
                    final isSelected = v.id == vehicle?.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${v.brand} ${v.name} (${v.plate})'),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val && v.id != null) {
                            setState(() => _selectedVehicle = v);
                            _loadRecords();
                          }
                        },
                        selectedColor: AppTheme.navy,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Chips Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Semua', 'Servis', 'Penggantian', 'Pemeriksaan', 'Lainnya'].map((chip) {
                  final isSelected = _selectedFilter == chip;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(l10n.translateCategory(chip)),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() => _selectedFilter = chip);
                      },
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      selectedColor: AppTheme.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : const Color(0xFFE2E9F3),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (vehicle == null)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 48, color: AppTheme.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      l10n.noVehicleTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.noVehicleDesc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            else if (_filteredRecords.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      '${l10n.noServiceHistoryTitle} (${vehicle.brand} ${vehicle.name})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.noServiceHistoryDesc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ..._filteredRecords.map((rec) => _buildRecordCard(rec, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(ServiceRecord rec, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.build_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.date,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.translateReminderTitle(rec.title),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatNumber(rec.mileage)} km • ${rec.workshop}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.translateVehicleStatus(rec.status),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Hash Info Bar (Blockchain verification)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'SHA-256: ${rec.hash.length >= 16 ? rec.hash.substring(0, 16) : rec.hash}...',
                    style: const TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Text(
                  rec.cost > 0 ? CurrencyService.instance.format(rec.cost) : '',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Blockchain Certificate Actions
          Row(
            children: [
              if (_generatingIds.contains(rec.id))
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Memproses Sertifikat PDF...',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      side: BorderSide(
                        color: _docCache.containsKey(rec.id) ? AppTheme.success : AppTheme.primary,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(
                      _docCache.containsKey(rec.id)
                          ? Icons.verified_rounded
                          : Icons.picture_as_pdf_outlined,
                      size: 15,
                      color: _docCache.containsKey(rec.id) ? AppTheme.success : AppTheme.primary,
                    ),
                    label: Text(
                      _docCache.containsKey(rec.id)
                          ? 'Sertifikat Blockchain'
                          : l10n.generatePdfCertificate,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _docCache.containsKey(rec.id) ? AppTheme.success : AppTheme.primary,
                      ),
                    ),
                    onPressed: () => _handleGeneratePdf(rec),
                  ),
                ),
                if (_docCache.containsKey(rec.id)) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.viewPdf,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.background,
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16, color: AppTheme.navy),
                    onPressed: () async {
                      final url = _docCache[rec.id]!.pdfUrl;
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    },
                  ),
                  IconButton(
                    tooltip: l10n.verifyBlockchain,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.background,
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: AppTheme.primary),
                    onPressed: () async {
                      final url = _docCache[rec.id]!.verificationUrl;
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    },
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
  }
}
