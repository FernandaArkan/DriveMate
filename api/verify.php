<?php

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/blockchain.php';
$config = require __DIR__ . '/config.php';

$wantsJson = false;
$acceptHeader = $_SERVER['HTTP_ACCEPT'] ?? '';
if (str_contains($acceptHeader, 'application/json') || (isset($_GET['format']) && $_GET['format'] === 'json')) {
    $wantsJson = true;
}

// 1. Read document_id from GET or POST
$documentId = trim((string) ($_GET['document_id'] ?? $_POST['document_id'] ?? ''));

// If JSON body was sent
if ($documentId === '' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $rawInput = file_get_contents('php://input');
    $jsonInput = json_decode($rawInput, true);
    if (is_array($jsonInput)) {
        $documentId = trim((string) ($jsonInput['document_id'] ?? ''));
    }
}

// Check if user uploaded a PDF file for direct integrity check
$uploadedPdfFile = $_FILES['pdf_file'] ?? null;
$uploadedHash = null;
$hasUploadedFile = false;
$fileMatch = null;

if ($uploadedPdfFile && is_uploaded_file($uploadedPdfFile['tmp_name'])) {
    $hasUploadedFile = true;
    $uploadedHash = hash_file('sha256', $uploadedPdfFile['tmp_name']);
}

// 2. State definition variables
$state = 'NOT_FOUND';
$statusTitle = 'ID Dokumen Tidak Ditemukan';
$statusDesc = 'Dokumen dengan ID ini tidak terdaftar di dalam sistem DriveMate.';
$statusBadgeClass = 'badge-danger';
$statusIcon = '❓';
$record = null;
$vehicle = null;
$serviceRecord = null;
$onChainInfo = null;

// 3. Query document from database
if ($documentId !== '') {
    try {
        $stmtDoc = $pdo->prepare('SELECT * FROM public.blockchain_records WHERE document_id = :id LIMIT 1');
        $stmtDoc->execute(['id' => $documentId]);
        $record = $stmtDoc->fetch();

        if ($record) {
            $svcId = (int) $record['service_record_id'];

            // Query service record details
            $stmtSvc = $pdo->prepare('SELECT * FROM public.service_records WHERE id = :id LIMIT 1');
            $stmtSvc->execute(['id' => $svcId]);
            $serviceRecord = $stmtSvc->fetch();

            if ($serviceRecord) {
                $vehId = (int) ($serviceRecord['vehicle_id'] ?? $serviceRecord['vehicleId'] ?? 1);
                $stmtVeh = $pdo->prepare('SELECT * FROM public.vehicles WHERE id = :id LIMIT 1');
                $stmtVeh->execute(['id' => $vehId]);
                $vehicle = $stmtVeh->fetch();
            }

            $registeredHash = strtolower(trim((string) $record['document_hash']));
            $dbStatus = strtolower(trim((string) ($record['verification_status'] ?? 'pending')));
            $txHash = $record['transaction_hash'] ?? null;

            // 4. Query Smart Contract via BlockchainService
            $blockchain = new BlockchainService($config);
            $onChainInfo = $blockchain->verifyDocumentOnChain($documentId, $registeredHash);

            // 5. Determine condition accurately according to specs
            if ($hasUploadedFile && $uploadedHash !== null) {
                if (strtolower($uploadedHash) !== $registeredHash) {
                    $state = 'HASH_MISMATCH';
                    $statusTitle = 'Integritas Gagal: Hash Tidak Cocok';
                    $statusDesc = 'Berkas PDF yang diunggah telah dimodifikasi atau rusak! Hash SHA-256 berkas tidak cocok dengan catatan yang sah.';
                    $statusBadgeClass = 'badge-danger';
                    $statusIcon = '⚠️';
                } else {
                    $fileMatch = true;
                }
            }

            if ($state !== 'HASH_MISMATCH') {
                if ($onChainInfo['status'] === 'network_error') {
                    $state = 'NETWORK_UNAVAILABLE';
                    $statusTitle = 'Layanan Blockchain Sedang Tidak Tersedia';
                    $statusDesc = 'Koneksi ke jaringan RPC blockchain mengalami gangguan. Catatan dokumen sah dan aman tersimpan di arsip digital DriveMate.';
                    $statusBadgeClass = 'badge-warning';
                    $statusIcon = '📡';
                } elseif ($onChainInfo['status'] === 'unconfigured') {
                    // Smart contract pending configuration
                    if ($dbStatus === 'failed') {
                        $state = 'TRANSACTION_FAILED';
                        $statusTitle = 'Pencatatan Blockchain Dibatalkan';
                        $statusDesc = 'Transaksi pencatatan dokumen ke smart contract dibatalkan atau mengalami kegagalan.';
                        $statusBadgeClass = 'badge-danger';
                        $statusIcon = '❌';
                    } else {
                        $state = 'PENDING_CONFIRMATION';
                        $statusTitle = 'Menunggu Konfirmasi Jaringan';
                        $statusDesc = 'Dokumen telah diterbitkan secara sah dan sedang menunggu konfirmasi pencatatan blok pada jaringan blockchain.';
                        $statusBadgeClass = 'badge-pending';
                        $statusIcon = '⏳';
                    }
                } elseif ($onChainInfo['status'] === 'mismatch') {
                    $state = 'HASH_MISMATCH';
                    $statusTitle = 'Integritas Gagal: Hash On-Chain Berbeda';
                    $statusDesc = 'Hash dokumen pada smart contract tidak cocok dengan dokumen ini.';
                    $statusBadgeClass = 'badge-danger';
                    $statusIcon = '⚠️';
                } elseif ($onChainInfo['status'] === 'verified') {
                    $state = 'VERIFIED';
                    $statusTitle = 'Dokumen Sah & Terverifikasi Blockchain';
                    $statusDesc = 'Keaslian dokumen terbukti 100% cocok dengan catatan transaksi permanen di smart contract blockchain.';
                    $statusBadgeClass = 'badge-success';
                    $statusIcon = '✅';
                } elseif ($dbStatus === 'failed') {
                    $state = 'TRANSACTION_FAILED';
                    $statusTitle = 'Pencatatan Blockchain Gagal';
                    $statusDesc = 'Transaksi pencatatan dokumen ke smart contract gagal dieksekusi oleh jaringan.';
                    $statusBadgeClass = 'badge-danger';
                    $statusIcon = '❌';
                } else {
                    $state = 'PENDING_CONFIRMATION';
                    $statusTitle = 'Menunggu Konfirmasi Blok';
                    $statusDesc = 'Transaksi sedang dalam antrean blok (mempool) pada jaringan ' . htmlspecialchars($onChainInfo['network_name']) . '.';
                    $statusBadgeClass = 'badge-pending';
                    $statusIcon = '⏳';
                }
            }
        }
    } catch (Throwable $e) {
        error_log('Verification query error: ' . $e->getMessage());
        $state = 'NETWORK_UNAVAILABLE';
        $statusTitle = 'Layanan Verifikasi Terganggu';
        $statusDesc = 'Terjadi gangguan koneksi pada server verifikasi: ' . $e->getMessage();
        $statusBadgeClass = 'badge-warning';
        $statusIcon = '⚠️';
    }
}

// Return JSON if requested
if ($wantsJson) {
    header('Content-Type: application/json; charset=utf-8');
    if ($state === 'NOT_FOUND') {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'state' => 'NOT_FOUND',
            'message' => $statusTitle,
            'description' => $statusDesc,
            'document_id' => $documentId,
        ]);
        exit;
    }

    echo json_encode([
        'success' => true,
        'state' => $state,
        'status_title' => $statusTitle,
        'status_description' => $statusDesc,
        'data' => [
            'document_id' => $documentId,
            'registered_hash' => $record['document_hash'] ?? null,
            'uploaded_hash' => $uploadedHash,
            'is_hash_match' => ($hasUploadedFile ? ($uploadedHash === strtolower($record['document_hash'] ?? '')) : null),
            'verification_status' => $record['verification_status'] ?? null,
            'transaction_hash' => $record['transaction_hash'] ?? null,
            'network_name' => $record['network_name'] ?? $config['blockchain_network_name'],
            'contract_address' => $record['contract_address'] ?? $config['blockchain_contract_address'],
            'created_at' => $record['created_at'] ?? null,
            'blockchain_info' => $onChainInfo,
            'vehicle' => $vehicle ? [
                'name' => $vehicle['name'],
                'brand' => $vehicle['brand'] ?? '',
                'plate_number' => $vehicle['plate_number'] ?? $vehicle['plate'] ?? '',
                'year' => (int) $vehicle['year'],
            ] : null,
            'service_record' => $serviceRecord ? [
                'id' => (int) $serviceRecord['id'],
                'title' => $serviceRecord['title'] ?? '',
                'date' => $serviceRecord['date'] ?? '',
                'cost' => (int) ($serviceRecord['cost'] ?? 0),
                'workshop' => $serviceRecord['workshop'] ?? '',
            ] : null,
        ],
    ]);
    exit;
}

// Return HTML Page
header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verifikasi Sertifikat Servis — DriveMate</title>
    <style>
        :root {
            --primary: #0A66C2;
            --navy: #002B49;
            --bg: #F4F7FB;
            --text-primary: #1E293B;
            --text-secondary: #64748B;
            --success: #16A34A;
            --danger: #DC2626;
            --warning: #D97706;
            --border: #E2E8F0;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
        body { background: var(--bg); color: var(--text-primary); line-height: 1.5; padding: 24px 16px; min-height: 100vh; }
        .container { max-width: 680px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 24px; }
        .header h1 { font-size: 22px; font-weight: 800; color: var(--navy); display: flex; align-items: center; justify-content: center; gap: 8px; }
        .header p { font-size: 13px; color: var(--text-secondary); margin-top: 4px; }
        .card { background: #fff; border-radius: 18px; border: 1px solid var(--border); box-shadow: 0 4px 20px rgba(0,0,0,0.04); overflow: hidden; margin-bottom: 20px; }
        .status-hero { padding: 28px 24px; text-align: center; }
        .status-hero.VERIFIED { background: linear-gradient(180deg, #F0FDF4 0%, #FFFFFF 100%); }
        .status-hero.HASH_MISMATCH, .status-hero.NOT_FOUND, .status-hero.TRANSACTION_FAILED { background: linear-gradient(180deg, #FEF2F2 0%, #FFFFFF 100%); }
        .status-hero.PENDING_CONFIRMATION { background: linear-gradient(180deg, #FFFBEB 0%, #FFFFFF 100%); }
        .status-hero.NETWORK_UNAVAILABLE { background: linear-gradient(180deg, #F1F5F9 0%, #FFFFFF 100%); }
        .status-icon { font-size: 44px; margin-bottom: 12px; }
        .status-title { font-size: 20px; font-weight: 800; color: var(--text-primary); margin-bottom: 6px; }
        .status-desc { font-size: 13.5px; color: var(--text-secondary); max-width: 520px; margin: 0 auto; }
        .badge { display: inline-block; padding: 5px 14px; border-radius: 20px; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; margin-top: 14px; }
        .badge-success { background: #DCFCE7; color: #15803D; }
        .badge-danger { background: #FEE2E2; color: #B91C1C; }
        .badge-pending { background: #FEF3C7; color: #B45309; }
        .badge-warning { background: #E2E8F0; color: #475569; }
        .card-body { padding: 20px 24px; }
        .section-header { font-size: 13px; font-weight: 700; color: var(--navy); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 14px; border-bottom: 1px solid var(--border); padding-bottom: 6px; display: flex; justify-content: space-between; align-items: center; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px 20px; margin-bottom: 18px; }
        @media (max-width: 480px) { .info-grid { grid-template-columns: 1fr; } }
        .info-item .label { font-size: 11px; font-weight: 600; color: var(--text-secondary); text-transform: uppercase; margin-bottom: 2px; }
        .info-item .val { font-size: 13.5px; font-weight: 700; color: var(--text-primary); word-break: break-all; }
        .code-box { background: #F8FAFC; border: 1px solid var(--border); border-radius: 10px; padding: 10px 12px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 11px; color: #334155; word-break: break-all; margin-top: 4px; }
        .upload-section { background: #F8FAFC; border: 2px dashed #CBD5E1; border-radius: 14px; padding: 20px; text-align: center; margin-top: 14px; }
        .upload-section p { font-size: 12px; color: var(--text-secondary); margin-bottom: 10px; }
        .btn { display: inline-flex; align-items: center; justify-content: center; gap: 8px; padding: 10px 18px; border-radius: 10px; font-size: 13px; font-weight: 700; cursor: pointer; text-decoration: none; border: none; transition: background 0.2s; }
        .btn-primary { background: var(--primary); color: #fff; }
        .btn-primary:hover { background: #08539e; }
        .btn-outline { background: #fff; border: 1px solid var(--border); color: var(--text-primary); }
        .btn-outline:hover { background: #F1F5F9; }
        .actions-row { display: flex; gap: 10px; justify-content: center; margin-top: 16px; flex-wrap: wrap; }
        .footer { text-align: center; font-size: 11.5px; color: var(--text-secondary); margin-top: 24px; padding-bottom: 16px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚗 DriveMate</h1>
            <p>Portal Verifikasi Publik Integritas Dokumen & Smart Contract</p>
        </div>

        <div class="card">
            <div class="status-hero <?= htmlspecialchars($state) ?>">
                <div class="status-icon"><?= $statusIcon ?></div>
                <h2 class="status-title"><?= htmlspecialchars($statusTitle) ?></h2>
                <p class="status-desc"><?= htmlspecialchars($statusDesc) ?></p>
                <div class="badge <?= htmlspecialchars($statusBadgeClass) ?>"><?= htmlspecialchars($state) ?></div>
            </div>

            <?php if ($record): ?>
            <div class="card-body">
                <div class="section-header">
                    <span>Identitas Kendaraan & Servis</span>
                    <span style="font-size: 11px; font-weight: 600; color: var(--primary);">Dokumen Sah</span>
                </div>

                <div class="info-grid">
                    <div class="info-item">
                        <div class="label">Kendaraan</div>
                        <div class="val"><?= htmlspecialchars(($vehicle['brand'] ?? '') . ' ' . ($vehicle['name'] ?? 'Kendaraan')) ?></div>
                    </div>
                    <div class="info-item">
                        <div class="label">Nomor Polisi</div>
                        <div class="val" style="color: var(--primary); font-size: 15px;"><?= htmlspecialchars($vehicle['plate_number'] ?? $vehicle['plate'] ?? '-') ?></div>
                    </div>
                    <div class="info-item">
                        <div class="label">Tanggal Pelaksanaan</div>
                        <div class="val"><?= htmlspecialchars($serviceRecord['date'] ?? '-') ?></div>
                    </div>
                    <div class="info-item">
                        <div class="label">Pekerjaan Servis</div>
                        <div class="val"><?= htmlspecialchars($serviceRecord['title'] ?? '-') ?></div>
                    </div>
                    <div class="info-item">
                        <div class="label">Bengkel Pelaksana</div>
                        <div class="val"><?= htmlspecialchars($serviceRecord['workshop'] ?? '-') ?></div>
                    </div>
                    <div class="info-item">
                        <div class="label">Total Biaya</div>
                        <div class="val" style="color: var(--success);">Rp <?= number_format((int) ($serviceRecord['cost'] ?? 0), 0, ',', '.') ?></div>
                    </div>
                </div>

                <div class="section-header">
                    <span>Bukti Kriptografi & Blockchain</span>
                </div>

                <div style="margin-bottom: 14px;">
                    <div class="info-item">
                        <div class="label">ID Dokumen (UUID)</div>
                        <div class="code-box"><?= htmlspecialchars($documentId) ?></div>
                    </div>
                </div>

                <div style="margin-bottom: 14px;">
                    <div class="info-item">
                        <div class="label">Hash Dokumen PDF Terdaftar (SHA-256)</div>
                        <div class="code-box"><?= htmlspecialchars($record['document_hash'] ?? '-') ?></div>
                    </div>
                </div>

                <?php if ($hasUploadedFile): ?>
                <div style="margin-bottom: 14px;">
                    <div class="info-item">
                        <div class="label">Hash File yang Diunggah (SHA-256)</div>
                        <div class="code-box" style="border-color: <?= $fileMatch ? 'var(--success)' : 'var(--danger)' ?>; color: <?= $fileMatch ? 'var(--success)' : 'var(--danger)' ?>;">
                            <?= htmlspecialchars($uploadedHash ?? '-') ?>
                            (<?= $fileMatch ? 'COCOK 100%' : 'TIDAK COCOK!' ?>)
                        </div>
                    </div>
                </div>
                <?php endif; ?>

                <div class="info-grid">
                    <div class="info-item">
                        <div class="label">Jaringan Blockchain</div>
                        <div class="val"><?= htmlspecialchars($record['network_name'] ?? $config['blockchain_network_name']) ?></div>
                    </div>
                    <div class="info-item">
                        <div class="label">Status Verifikasi</div>
                        <div class="val"><?= htmlspecialchars(ucfirst($record['verification_status'] ?? 'pending')) ?></div>
                    </div>
                    <div class="info-item" style="grid-column: 1 / -1;">
                        <div class="label">Alamat Smart Contract</div>
                        <div class="code-box"><?= htmlspecialchars(!empty($record['contract_address']) ? $record['contract_address'] : ($config['blockchain_contract_address'] ?: 'Menunggu konfigurasi environment')) ?></div>
                    </div>
                    <div class="info-item" style="grid-column: 1 / -1;">
                        <div class="label">Hash Transaksi (Tx Hash)</div>
                        <div class="code-box"><?= htmlspecialchars(!empty($record['transaction_hash']) ? $record['transaction_hash'] : 'Belum tercatat on-chain / Pending') ?></div>
                    </div>
                </div>

                <div class="upload-section">
                    <h4 style="font-size: 13px; font-weight: 700; margin-bottom: 4px;">Uji Mandiri Berkas PDF Anda</h4>
                    <p>Unggah file sertifikat PDF yang Anda unduh untuk membandingkan hash SHA-256 berkas dengan data blockchain secara real-time:</p>
                    <form action="verify.php?document_id=<?= urlencode($documentId) ?>" method="POST" enctype="multipart/form-data">
                        <input type="hidden" name="document_id" value="<?= htmlspecialchars($documentId) ?>">
                        <input type="file" name="pdf_file" accept="application/pdf" required style="font-size: 12px; margin-bottom: 10px;">
                        <br>
                        <button type="submit" class="btn btn-outline" style="font-size: 12px; padding: 6px 14px;">🔍 Uji Keaslian Berkas</button>
                    </form>
                </div>

                <div class="actions-row">
                    <a href="view_pdf.php?document_id=<?= urlencode($documentId) ?>" target="_blank" class="btn btn-outline">Lihat PDF Asli</a>
                    <a href="view_pdf.php?document_id=<?= urlencode($documentId) ?>&download=1" class="btn btn-primary">Unduh Sertifikat PDF</a>
                </div>
            </div>
            <?php else: ?>
            <div class="card-body" style="text-align: center; padding: 30px;">
                <p style="color: var(--text-secondary); margin-bottom: 20px;">
                    Pastikan Anda memasukkan ID Dokumen yang valid atau memindai QR Code resmi dari sertifikat servis DriveMate.
                </p>
                <form action="verify.php" method="GET" style="display: flex; gap: 8px; max-width: 420px; margin: 0 auto;">
                    <input type="text" name="document_id" placeholder="Masukkan Document ID (UUID)..." value="<?= htmlspecialchars($documentId) ?>" required style="flex: 1; padding: 9px 12px; border: 1px solid var(--border); border-radius: 8px; font-size: 13px;">
                    <button type="submit" class="btn btn-primary" style="padding: 9px 16px;">Cari</button>
                </form>
            </div>
            <?php endif; ?>
        </div>

        <div class="footer">
            <p>© <?= date('Y') ?> DriveMate — Personal Vehicle Assistant. Seluruh hak cipta dilindungi.</p>
            <p style="margin-top: 4px;">Sistem Integritas Digital & Validasi Kriptografi Blockchain</p>
        </div>
    </div>
</body>
</html>
