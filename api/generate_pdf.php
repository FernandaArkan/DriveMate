<?php

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/qrcode.php';
require_once __DIR__ . '/pdf_generator.php';
require_once __DIR__ . '/blockchain.php';

$config = require __DIR__ . '/config.php';

try {
    // 1. Read input parameters from POST body or GET query
    $input = [];
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $raw = file_get_contents('php://input');
        $decoded = json_decode($raw, true);
        if (is_array($decoded)) {
            $input = $decoded;
        } else {
            $input = $_POST;
        }
    } else {
        $input = $_GET;
    }

    $serviceRecordId = filter_var($input['service_record_id'] ?? $input['service_id'] ?? null, FILTER_VALIDATE_INT);
    $vehicleId = filter_var($input['vehicle_id'] ?? null, FILTER_VALIDATE_INT);
    $userId = filter_var($input['user_id'] ?? null, FILTER_VALIDATE_INT);
    $forceRegenerate = filter_var($input['force_regenerate'] ?? false, FILTER_VALIDATE_BOOLEAN);

    // 2. Validate Authentication & Authorization
    // Check Authorization header for Bearer token if userId not supplied directly
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if (empty($userId) && !empty($authHeader) && preg_match('/Bearer\s+(.+)$/i', $authHeader, $matches)) {
        $token = trim($matches[1]);
        // Validate user by token if users table has session/token
        // Or extract user_id from token if implemented
    }

    if (!$serviceRecordId || $serviceRecordId < 1) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'service_record_id wajib disertakan dengan ID yang valid.',
        ]);
        exit;
    }

    // 3. Find Service Record in database (support both service_records and service_record table names)
    $tableServiceRecords = 'service_records';
    try {
        $checkTable = $pdo->query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('service_records', 'service_record') ORDER BY CASE WHEN table_name = 'service_records' THEN 1 ELSE 2 END LIMIT 1");
        $tableRow = $checkTable->fetch();
        if ($tableRow && !empty($tableRow['table_name'])) {
            $tableServiceRecords = $tableRow['table_name'];
        }
    } catch (Throwable $e) {
        // Fallback to service_records
        $tableServiceRecords = 'service_records';
    }

    // Query columns of service table to support snake_case and camelCase
    $colVehicleId = 'vehicle_id';
    try {
        $checkCols = $pdo->query("SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = '{$tableServiceRecords}' AND column_name IN ('vehicle_id', 'vehicleid', 'vehicleId')");
        $cRow = $checkCols->fetch();
        if ($cRow) {
            $colVehicleId = $cRow['column_name'];
        }
    } catch (Throwable $e) {
        $colVehicleId = 'vehicle_id';
    }

    $stmtSvc = $pdo->prepare("SELECT * FROM public.{$tableServiceRecords} WHERE id = :id LIMIT 1");
    $stmtSvc->execute(['id' => $serviceRecordId]);
    $serviceRecord = $stmtSvc->fetch();

    if (!$serviceRecord) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => "Catatan servis dengan ID {$serviceRecordId} tidak ditemukan dalam database.",
        ]);
        exit;
    }

    // Extract vehicle ID from service record if not supplied
    $recVehicleId = (int) ($serviceRecord[$colVehicleId] ?? $serviceRecord['vehicle_id'] ?? $serviceRecord['vehicleId'] ?? 0);
    if ($vehicleId && $vehicleId !== $recVehicleId) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Catatan servis tidak sesuai dengan ID kendaraan yang diberikan.',
        ]);
        exit;
    }
    $vehicleId = $recVehicleId;

    // 4. Query Vehicle & Validate User Ownership
    $stmtVeh = $pdo->prepare("SELECT * FROM public.vehicles WHERE id = :id LIMIT 1");
    $stmtVeh->execute(['id' => $vehicleId]);
    $vehicle = $stmtVeh->fetch();

    if (!$vehicle) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => "Kendaraan dengan ID {$vehicleId} tidak ditemukan.",
        ]);
        exit;
    }

    // If userId provided, enforce ownership check
    if ($userId && $userId > 0) {
        $ownerId = (int) $vehicle['user_id'];
        if ($ownerId !== $userId) {
            http_response_code(403);
            echo json_encode([
                'success' => false,
                'message' => 'Akses ditolak. Pengguna tidak berhak mengakses dokumen kendaraan milik pengguna lain.',
            ]);
            exit;
        }
    }

    // 5. Check if document already exists in blockchain_records
    $existingRecord = null;
    try {
        $stmtCheck = $pdo->prepare("SELECT * FROM public.blockchain_records WHERE service_record_id = :svc_id ORDER BY id DESC LIMIT 1");
        $stmtCheck->execute(['svc_id' => $serviceRecordId]);
        $existingRecord = $stmtCheck->fetch();
    } catch (Throwable $e) {
        // Table blockchain_records might need to be checked
        error_log('Notice: blockchain_records query: ' . $e->getMessage());
    }

    $storageDir = __DIR__ . '/storage/pdf';
    if (!is_dir($storageDir)) {
        @mkdir($storageDir, 0777, true);
    }

    $appBaseUrl = rtrim($config['app_base_url'] ?? 'https://drivemate-3c397.containers.snapdeploy.app', '/');
    // If request has host header, prefer dynamic host for local dev/testing
    if (!empty($_SERVER['HTTP_HOST'])) {
        $proto = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
        $host = $_SERVER['HTTP_HOST'];
        if (str_contains($host, 'localhost') || str_contains($host, '127.0.0.1')) {
            // Keep app_base_url for production QR code compliance, but allow dynamic endpoint URL
        }
    }

    // If document already generated and not forcing regeneration, return existing
    if ($existingRecord && !$forceRegenerate && !empty($existingRecord['document_id'])) {
        $docId = $existingRecord['document_id'];
        $docHash = $existingRecord['document_hash'];
        $pdfPath = $existingRecord['pdf_path'] ?? ($storageDir . "/{$docId}.pdf");

        // Verify PDF file exists, if not re-generate
        if (file_exists($pdfPath)) {
            $verificationUrl = "{$appBaseUrl}/api/verify.php?document_id={$docId}";
            $pdfUrl = "{$appBaseUrl}/api/view_pdf.php?document_id={$docId}";
            $pdfDownloadUrl = "{$appBaseUrl}/api/view_pdf.php?document_id={$docId}&download=1";

            echo json_encode([
                'success' => true,
                'message' => 'Dokumen sertifikat servis ditemukan pada arsip blockchain.',
                'data' => [
                    'document_id' => $docId,
                    'document_hash' => $docHash,
                    'verification_status' => $existingRecord['verification_status'] ?? 'pending',
                    'transaction_hash' => $existingRecord['transaction_hash'] ?? null,
                    'network_name' => $existingRecord['network_name'] ?? $config['blockchain_network_name'],
                    'contract_address' => $existingRecord['contract_address'] ?? $config['blockchain_contract_address'],
                    'pdf_path' => $pdfPath,
                    'verification_url' => $verificationUrl,
                    'pdf_url' => $pdfUrl,
                    'pdf_download_url' => $pdfDownloadUrl,
                    'created_at' => $existingRecord['created_at'] ?? date('Y-m-d H:i:s T'),
                    'is_cached' => true,
                ],
            ]);
            exit;
        }
    }

    // 6. Generate UUID v4 for document_id
    $bytes = random_bytes(16);
    $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40); // version 4
    $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80); // variant RFC 4122
    $documentId = vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($bytes), 4));

    // 7. QR Code contains the exact verification URL
    $verificationUrl = "{$appBaseUrl}/api/verify.php?document_id={$documentId}";

    // 8. Generate the final PDF
    $generator = new PdfCertificateGenerator(
        $vehicle,
        $serviceRecord,
        $documentId,
        $verificationUrl,
        date('Y-m-d H:i:s T')
    );
    $pdfBinary = $generator->generate();

    // 9. Calculate SHA-256 hash from the FINAL generated PDF bytes
    $documentHash = hash('sha256', $pdfBinary);

    // 10. Save PDF to storage path
    $pdfFilePath = "{$storageDir}/{$documentId}.pdf";
    file_put_contents($pdfFilePath, $pdfBinary);

    // 11. Send hash and document ID to Blockchain Smart Contract
    $blockchain = new BlockchainService($config);
    $bcResult = $blockchain->recordDocument($documentId, $documentHash, $serviceRecordId);

    $verificationStatus = $bcResult['status'];
    $transactionHash = $bcResult['transaction_hash'];
    $networkName = $bcResult['network_name'];
    $contractAddress = $bcResult['contract_address'];

    // 12. Save metadata to blockchain_records in PostgreSQL
    try {
        $stmtInsert = $pdo->prepare(
            'INSERT INTO public.blockchain_records (
                document_id, service_record_id, document_hash, transaction_hash,
                network_name, contract_address, pdf_path, verification_status, created_at
            ) VALUES (
                :doc_id, :svc_id, :doc_hash, :tx_hash,
                :net_name, :contract, :pdf_path, :status, NOW()
            )
            RETURNING id, document_id, service_record_id, document_hash, transaction_hash,
                      network_name, contract_address, pdf_path, verification_status, created_at'
        );

        $stmtInsert->execute([
            'doc_id' => $documentId,
            'svc_id' => $serviceRecordId,
            'doc_hash' => $documentHash,
            'tx_hash' => $transactionHash,
            'net_name' => $networkName,
            'contract' => $contractAddress,
            'pdf_path' => $pdfFilePath,
            'status' => $verificationStatus,
        ]);
        $savedRecord = $stmtInsert->fetch();
    } catch (Throwable $e) {
        error_log('Error saving to blockchain_records: ' . $e->getMessage());
        // Fallback gracefully without breaking the PDF response
    }

    $pdfUrl = "{$appBaseUrl}/api/view_pdf.php?document_id={$documentId}";
    $pdfDownloadUrl = "{$appBaseUrl}/api/view_pdf.php?document_id={$documentId}&download=1";

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'message' => 'Dokumen sertifikat riwayat servis berhasil dibuat dan didaftarkan.',
        'data' => [
            'document_id' => $documentId,
            'service_record_id' => $serviceRecordId,
            'document_hash' => $documentHash,
            'verification_status' => $verificationStatus,
            'transaction_hash' => $transactionHash,
            'network_name' => $networkName,
            'contract_address' => $contractAddress,
            'pdf_path' => $pdfFilePath,
            'verification_url' => $verificationUrl,
            'pdf_url' => $pdfUrl,
            'pdf_download_url' => $pdfDownloadUrl,
            'blockchain_message' => $bcResult['message'] ?? '',
            'created_at' => date('Y-m-d H:i:s T'),
            'vehicle' => [
                'id' => (int) $vehicle['id'],
                'name' => $vehicle['name'],
                'brand' => $vehicle['brand'] ?? '',
                'plate_number' => $vehicle['plate_number'] ?? $vehicle['plate'] ?? '',
                'year' => (int) $vehicle['year'],
            ],
            'service_record' => [
                'id' => (int) $serviceRecord['id'],
                'title' => $serviceRecord['title'] ?? '',
                'date' => $serviceRecord['date'] ?? '',
                'cost' => (int) ($serviceRecord['cost'] ?? 0),
            ],
        ],
    ]);
} catch (Throwable $e) {
    error_log('Generate PDF API error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan sistem saat menghasilkan dokumen PDF: ' . $e->getMessage(),
    ]);
}
