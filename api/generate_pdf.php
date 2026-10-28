<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/qrcode.php';
require_once __DIR__ . '/pdf_generator.php';

$config = require __DIR__ . '/config.php';

function respond(int $status, array $payload): never {
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

try {
    $input = [];
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
        $raw = file_get_contents('php://input');
        $decoded = json_decode($raw ?: '', true);
        $input = is_array($decoded) ? $decoded : $_POST;
    } else {
        $input = $_GET;
    }

    $serviceRecordId = filter_var(
        $input['service_record_id'] ?? $input['service_id'] ?? null,
        FILTER_VALIDATE_INT
    );
    $vehicleId = filter_var($input['vehicle_id'] ?? null, FILTER_VALIDATE_INT);
    $userId = filter_var($input['user_id'] ?? null, FILTER_VALIDATE_INT);
    $forceRegenerate = filter_var($input['force_regenerate'] ?? false, FILTER_VALIDATE_BOOLEAN);

    if (!$serviceRecordId || $serviceRecordId < 1) {
        respond(400, ['success' => false, 'message' => 'service_record_id wajib diisi dengan ID yang valid.']);
    }

    // Cari tabel servis yang tersedia, mengutamakan nama service_records.
    $tableServiceRecords = 'service_records';
    $tableCheck = $pdo->query(
        "SELECT table_name FROM information_schema.tables
         WHERE table_schema = 'public'
           AND table_name IN ('service_records', 'service_record')
         ORDER BY CASE WHEN table_name = 'service_records' THEN 1 ELSE 2 END
         LIMIT 1"
    );
    $tableRow = $tableCheck->fetch(PDO::FETCH_ASSOC);
    if (!empty($tableRow['table_name'])) {
        $candidate = $tableRow['table_name'];
        if (in_array($candidate, ['service_records', 'service_record'], true)) {
            $tableServiceRecords = $candidate;
        }
    }

    $columnsStmt = $pdo->prepare(
        "SELECT column_name FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = :table_name"
    );
    $columnsStmt->execute(['table_name' => $tableServiceRecords]);
    $columns = $columnsStmt->fetchAll(PDO::FETCH_COLUMN);
    $vehicleColumn = null;
    foreach (['vehicle_id', 'vehicleid', 'vehicleId'] as $candidate) {
        if (in_array($candidate, $columns, true)) {
            $vehicleColumn = $candidate;
            break;
        }
    }
    if ($vehicleColumn === null) {
        respond(500, ['success' => false, 'message' => 'Kolom kendaraan pada tabel servis tidak ditemukan.']);
    }

    $stmtSvc = $pdo->prepare("SELECT * FROM public.{$tableServiceRecords} WHERE id = :id LIMIT 1");
    $stmtSvc->execute(['id' => $serviceRecordId]);
    $serviceRecord = $stmtSvc->fetch(PDO::FETCH_ASSOC);
    if ($serviceRecord) {
    $serviceRecord['title'] = $serviceRecord['description'] ?? '';
    $serviceRecord['date'] = $serviceRecord['service_date'] ?? '';
}

    $resolvedVehicleId = (int)($serviceRecord[$vehicleColumn] ?? 0);
    if ($vehicleId && $vehicleId !== $resolvedVehicleId) {
        respond(400, ['success' => false, 'message' => 'Catatan servis tidak sesuai dengan kendaraan yang diberikan.']);
    }

    $stmtVeh = $pdo->prepare('SELECT * FROM public.vehicles WHERE id = :id LIMIT 1');
    $stmtVeh->execute(['id' => $resolvedVehicleId]);
    $vehicle = $stmtVeh->fetch(PDO::FETCH_ASSOC);
    if (!$vehicle) {
        respond(404, ['success' => false, 'message' => 'Data kendaraan tidak ditemukan.']);
    }

    // Cek kepemilikan bila user_id dikirim oleh aplikasi.
    if ($userId && $userId > 0 && (int)($vehicle['user_id'] ?? 0) !== $userId) {
        respond(403, ['success' => false, 'message' => 'Akses ditolak: kendaraan bukan milik pengguna ini.']);
    }

    $storageDir = __DIR__ . '/storage/pdf';
    if (!is_dir($storageDir) && !mkdir($storageDir, 0775, true) && !is_dir($storageDir)) {
        throw new RuntimeException('Folder penyimpanan PDF tidak dapat dibuat.');
    }

    $appBaseUrl = rtrim((string)($config['app_base_url'] ?? 'https://drivemate-3c397.containers.snapdeploy.app'), '/');

    // Ambil dokumen sebelumnya jika tersedia dan tidak diminta dibuat ulang.
    $existingRecord = null;
    try {
        $stmtExisting = $pdo->prepare(
            'SELECT * FROM public.blockchain_records WHERE service_record_id = :service_id ORDER BY id DESC LIMIT 1'
        );
        $stmtExisting->execute(['service_id' => $serviceRecordId]);
        $existingRecord = $stmtExisting->fetch(PDO::FETCH_ASSOC);
    } catch (Throwable $ignored) {
        // Tabel metadata harus tersedia untuk menyimpan arsip verifikasi.
    }

    if ($existingRecord && !$forceRegenerate && !empty($existingRecord['document_id'])) {
        $existingId = (string)$existingRecord['document_id'];
        $existingPath = (string)($existingRecord['pdf_path'] ?? ($storageDir . '/' . $existingId . '.pdf'));
        if (is_file($existingPath)) {
            respond(200, [
                'success' => true,
                'message' => 'Sertifikat yang sudah ada ditemukan.',
                'data' => [
                    'document_id' => $existingId,
                    'document_hash' => $existingRecord['document_hash'],
                    'verification_status' => 'hash_verification_available',
                    'verification_method' => 'SHA-256 dibandingkan dengan hash referensi di PostgreSQL; bukan blockchain.',
                    'verification_url' => $appBaseUrl . '/api/verify.php?document_id=' . rawurlencode($existingId),
                    'pdf_url' => $appBaseUrl . '/api/view_pdf.php?document_id=' . rawurlencode($existingId),
                    'pdf_download_url' => $appBaseUrl . '/api/view_pdf.php?document_id=' . rawurlencode($existingId) . '&download=1',
                    'is_cached' => true
                ]
            ]);
        }
    }

    // UUID v4 untuk ID dokumen.
    $bytes = random_bytes(16);
    $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
    $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
    $hex = bin2hex($bytes);
    $documentId = substr($hex, 0, 8) . '-' . substr($hex, 8, 4) . '-' .
                  substr($hex, 12, 4) . '-' . substr($hex, 16, 4) . '-' . substr($hex, 20, 12);

    $verificationUrl = $appBaseUrl . '/api/verify.php?document_id=' . rawurlencode($documentId);

    // Gunakan generator PDF yang sudah ada di proyek.
    $generator = new PdfCertificateGenerator(
        $vehicle,
        $serviceRecord,
        $documentId,
        $verificationUrl,
        date('Y-m-d H:i:s T')
    );
    $pdfBinary = $generator->generate();
    if (!is_string($pdfBinary) || $pdfBinary === '') {
        throw new RuntimeException('Generator PDF tidak menghasilkan isi PDF.');
    }

    // Hash dihitung dari byte PDF final.
    $documentHash = hash('sha256', $pdfBinary);
    $pdfFilePath = $storageDir . '/' . $documentId . '.pdf';
    if (file_put_contents($pdfFilePath, $pdfBinary, LOCK_EX) === false) {
        throw new RuntimeException('PDF gagal disimpan.');
    }

    // Tidak memanggil blockchain.php. Hash referensi disimpan di database.
    // Status "pending" hanya menjaga kompatibilitas CHECK constraint tabel lama.
    $stmtInsert = $pdo->prepare(
        'INSERT INTO public.blockchain_records
            (document_id, service_record_id, document_hash, transaction_hash,
             network_name, contract_address, pdf_path, verification_status, created_at)
         VALUES
            (:document_id, :service_record_id, :document_hash, NULL,
             :network_name, NULL, :pdf_path, :verification_status, NOW())
         RETURNING id, document_id, service_record_id, document_hash, pdf_path, created_at'
    );
    $stmtInsert->execute([
        'document_id' => $documentId,
        'service_record_id' => $serviceRecordId,
        'document_hash' => $documentHash,
        'network_name' => 'PostgreSQL SHA-256 (tanpa blockchain)',
        'pdf_path' => $pdfFilePath,
        'verification_status' => 'pending'
    ]);

    respond(201, [
        'success' => true,
        'message' => 'PDF sertifikat berhasil dibuat. Hash referensi disimpan di PostgreSQL.',
        'data' => [
            'document_id' => $documentId,
            'service_record_id' => $serviceRecordId,
            'document_hash' => $documentHash,
            'verification_status' => 'hash_verification_available',
            'verification_method' => 'SHA-256 dibandingkan dengan hash referensi di PostgreSQL; bukan blockchain.',
            'transaction_hash' => null,
            'network_name' => 'PostgreSQL SHA-256 (tanpa blockchain)',
            'contract_address' => null,
            'pdf_path' => $pdfFilePath,
            'verification_url' => $verificationUrl,
            'pdf_url' => $appBaseUrl . '/api/view_pdf.php?document_id=' . rawurlencode($documentId),
            'pdf_download_url' => $appBaseUrl . '/api/view_pdf.php?document_id=' . rawurlencode($documentId) . '&download=1'
        ]
    ]);
} catch (Throwable $e) {
    error_log('Generate PDF/hash verification error: ' . $e->getMessage());
    respond(500, [
        'success' => false,
        'message' => 'Gagal membuat sertifikat PDF.',
        'detail' => $e->getMessage()
    ]);
}
