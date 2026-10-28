<?php

require_once __DIR__ . '/db.php';

$documentId = trim((string) ($_GET['document_id'] ?? ''));
$isDownload = !empty($_GET['download']);

if ($documentId === '' || !preg_match('/^[a-f0-9\-]{36}$/i', $documentId)) {
    http_response_code(400);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'message' => 'Parameter document_id tidak valid.',
    ]);
    exit;
}

$pdfPath = __DIR__ . "/storage/pdf/{$documentId}.pdf";

// If PDF file exists on disk, stream it
if (file_exists($pdfPath) && is_readable($pdfPath)) {
    $fileSize = filesize($pdfPath);
    $disposition = $isDownload ? 'attachment' : 'inline';

    header('Content-Type: application/pdf');
    header("Content-Disposition: {$disposition}; filename=\"DriveMate-Service-{$documentId}.pdf\"");
    header("Content-Length: {$fileSize}");
    header('Cache-Control: private, max-age=86400');
    header('Accept-Ranges: bytes');

    readfile($pdfPath);
    exit;
}

// Check database to see if document is registered
try {
    $stmt = $pdo->prepare("SELECT * FROM public.blockchain_records WHERE document_id = :id LIMIT 1");
    $stmt->execute(['id' => $documentId]);
    $doc = $stmt->fetch();

    if (!$doc) {
        http_response_code(404);
        header('Content-Type: text/html; charset=utf-8');
        echo "<!DOCTYPE html><html><head><title>Dokumen Tidak Ditemukan</title><meta name='viewport' content='width=device-width, initial-scale=1.0'><style>body{font-family:sans-serif;text-align:center;padding:50px;background:#f8fafc;color:#1e293b;}h1{color:#ef4444;}</style></head><body><h1>404 — Dokumen Tidak Ditemukan</h1><p>ID Dokumen <code>" . htmlspecialchars($documentId) . "</code> tidak terdaftar di sistem DriveMate.</p></body></html>";
        exit;
    }

    // Attempt regeneration from database data if service record exists
    require_once __DIR__ . '/qrcode.php';
    require_once __DIR__ . '/pdf_generator.php';
    $config = require __DIR__ . '/config.php';

    $svcId = (int) $doc['service_record_id'];
    $stmtSvc = $pdo->prepare("SELECT * FROM public.service_records WHERE id = :id LIMIT 1");
    $stmtSvc->execute(['id' => $svcId]);
    $svc = $stmtSvc->fetch();

    if ($svc) {
        $vehId = (int) ($svc['vehicle_id'] ?? $svc['vehicleId'] ?? 1);
        $stmtVeh = $pdo->prepare("SELECT * FROM public.vehicles WHERE id = :id LIMIT 1");
        $stmtVeh->execute(['id' => $vehId]);
        $veh = $stmtVeh->fetch();

        if ($veh) {
            $appBaseUrl = rtrim($config['app_base_url'] ?? 'https://drivemate-3c397.containers.snapdeploy.app', '/');
            $verificationUrl = "{$appBaseUrl}/api/verify.php?document_id={$documentId}";

            $generator = new PdfCertificateGenerator($veh, $svc, $documentId, $verificationUrl, $doc['created_at'] ?? null);
            $pdfContent = $generator->generate();

            // Re-cache to disk
            @file_put_contents($pdfPath, $pdfContent);

            $disposition = $isDownload ? 'attachment' : 'inline';
            header('Content-Type: application/pdf');
            header("Content-Disposition: {$disposition}; filename=\"DriveMate-Service-{$documentId}.pdf\"");
            header("Content-Length: " . strlen($pdfContent));
            header('Cache-Control: private, max-age=86400');
            echo $pdfContent;
            exit;
        }
    }
} catch (Throwable $e) {
    error_log('view_pdf error: ' . $e->getMessage());
}

http_response_code(404);
header('Content-Type: application/json; charset=utf-8');
echo json_encode([
    'success' => false,
    'message' => 'Berkas PDF untuk dokumen ini tidak ditemukan pada server.',
]);
