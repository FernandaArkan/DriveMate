<?php

require_once __DIR__ . '/qrcode.php';

/**
 * Pure PHP PDF Certificate Generator
 * Generates official vehicle service certificates in PDF 1.4 format with zero external dependencies.
 */
class PdfCertificateGenerator
{
    private array $vehicle;
    private array $serviceRecord;
    private string $documentId;
    private string $verificationUrl;
    private string $generatedAt;

    public function __construct(
        array $vehicle,
        array $serviceRecord,
        string $documentId,
        string $verificationUrl,
        ?string $generatedAt = null
    ) {
        $this->vehicle = $vehicle;
        $this->serviceRecord = $serviceRecord;
        $this->documentId = $documentId;
        $this->verificationUrl = $verificationUrl;
        $this->generatedAt = $generatedAt ?? date('Y-m-d H:i:s T');
    }

    /**
     * Escape PDF string literal (parentheses, backslashes)
     */
    private static function escapePdfString(string $str): string
    {
        // Replace non-ASCII characters with safe ASCII equivalents
        $str = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $str);
        return str_replace(['\\', '(', ')'], ['\\\\', '\\(', '\\)'], $str);
    }

    /**
     * Generate the complete binary PDF string
     */
    public function generate(): string
    {
        $pageWidth = 595.28;  // A4 width in pt
        $pageHeight = 841.89; // A4 height in pt

        // 1. Build QR Code vector graphic stream
        $qrSize = 100.0;
        $qrX = $pageWidth - 50.0 - $qrSize; // Right aligned
        $qrY = 90.0; // Bottom section
        $qr = new QRCode($this->verificationUrl, QRCode::EC_M);
        $qrPdfStream = $qr->renderPdfStream($qrX, $qrY, $qrSize);

        // 2. Prepare text and data
        $brand = strtoupper(trim((string) ($this->vehicle['brand'] ?? '')));
        $model = trim((string) ($this->vehicle['model'] ?? $this->vehicle['name'] ?? ''));
        $vehicleName = trim((string) ($this->vehicle['name'] ?? ''));
        $plate = strtoupper(trim((string) ($this->vehicle['plate_number'] ?? $this->vehicle['plate'] ?? '-')));
        $year = (string) ($this->vehicle['year'] ?? '-');
        $mileage = number_format((int) ($this->serviceRecord['mileage'] ?? $this->vehicle['mileage'] ?? 0), 0, ',', '.') . ' KM';

        $svcId = (string) ($this->serviceRecord['id'] ?? '-');
        $svcDate = trim((string) ($this->serviceRecord['date'] ?? '-'));
        $svcType = trim((string) ($this->serviceRecord['service_type'] ?? $this->serviceRecord['serviceType'] ?? 'Servis Berkala'));
        $svcTitle = trim((string) ($this->serviceRecord['title'] ?? '-'));
        $workshop = trim((string) ($this->serviceRecord['workshop'] ?? 'DriveMate Official Workshop'));
        $cost = 'Rp ' . number_format((int) ($this->serviceRecord['cost'] ?? 0), 0, ',', '.');
        $status = trim((string) ($this->serviceRecord['status'] ?? 'Selesai'));
        $notes = trim((string) ($this->serviceRecord['notes'] ?? 'Pemeriksaan dan penggantian sesuai jadwal standar.'));
        if ($notes === '') {
            $notes = '-';
        }

        $localHash = trim((string) ($this->serviceRecord['hash'] ?? '-'));
        $prevHash = trim((string) ($this->serviceRecord['prev_hash'] ?? $this->serviceRecord['prevHash'] ?? '-'));

        // 3. Assemble PDF content stream
        $stream = "";

        // Background color of page (subtle grey-white)
        $stream .= "q\n";
        $stream .= "0.98 0.98 0.99 rg\n";
        $stream .= "0 0 {$pageWidth} {$pageHeight} re f\n";

        // Decorative top border (Primary blue: #0A66C2 -> 0.04 0.40 0.76)
        $stream .= "0.04 0.40 0.76 rg\n";
        $stream .= "0 " . ($pageHeight - 8) . " {$pageWidth} 8 re f\n";

        // Header Background Banner (Navy: #002B49 -> 0.0 0.17 0.29)
        $stream .= "0.0 0.17 0.29 rg\n";
        $stream .= "36 " . ($pageHeight - 110) . " " . ($pageWidth - 72) . " 94 re f\n";

        // Brand Title
        $stream .= "BT\n";
        $stream .= "/F1 16 Tf\n";
        $stream .= "1 1 1 rg\n";
        $stream .= "54 " . ($pageHeight - 48) . " Td\n";
        $stream .= "(" . self::escapePdfString("DRIVEMATE") . ") Tj\n";
        $stream .= "/F2 10 Tf\n";
        $stream .= "0.68 0.82 0.95 rg\n";
        $stream .= "110 0 Td\n";
        $stream .= "(" . self::escapePdfString("| PERSONAL VEHICLE ASSISTANT") . ") Tj\n";
        $stream .= "ET\n";

        // Certificate Title
        $stream .= "BT\n";
        $stream .= "/F1 14 Tf\n";
        $stream .= "1 1 1 rg\n";
        $stream .= "54 " . ($pageHeight - 72) . " Td\n";
        $stream .= "(" . self::escapePdfString("SERTIFIKAT RIWAYAT SERVIS KENDARAAN") . ") Tj\n";
        $stream .= "/F2 8.5 Tf\n";
        $stream .= "0.85 0.90 0.95 rg\n";
        $stream .= "0 -16 Td\n";
        $stream .= "(" . self::escapePdfString("OFFICIAL DIGITAL SERVICE RECORD & BLOCKCHAIN PROOF OF INTEGRITY") . ") Tj\n";
        $stream .= "ET\n";

        // Document Meta Badge (Right side of banner)
        $stream .= "BT\n";
        $stream .= "/F2 7.5 Tf\n";
        $stream .= "0.80 0.88 0.95 rg\n";
        $stream .= "380 " . ($pageHeight - 52) . " Td\n";
        $stream .= "(" . self::escapePdfString("ID DOKUMEN:") . ") Tj\n";
        $stream .= "/F3 8 Tf\n";
        $stream .= "1 1 1 rg\n";
        $stream .= "0 -12 Td\n";
        $stream .= "(" . self::escapePdfString($this->documentId) . ") Tj\n";
        $stream .= "/F2 7.5 Tf\n";
        $stream .= "0.80 0.88 0.95 rg\n";
        $stream .= "0 -12 Td\n";
        $stream .= "(" . self::escapePdfString("TANGGAL CETAK: " . $this->generatedAt) . ") Tj\n";
        $stream .= "ET\n";

        // White content card
        $cardX = 36.0;
        $cardY = 50.0;
        $cardW = $pageWidth - 72.0;
        $cardH = $pageHeight - 175.0;

        $stream .= "1 1 1 rg\n";
        $stream .= "0.89 0.91 0.94 RG\n";
        $stream .= "1 w\n";
        $stream .= "{$cardX} {$cardY} {$cardW} {$cardH} re B\n";

        // SECTION 1: IDENTITAS KENDARAAN
        $sec1Y = $pageHeight - 145;
        $stream .= "0.0 0.17 0.29 rg\n";
        $stream .= "{$cardX} {$sec1Y} {$cardW} 22 re f\n";
        $stream .= "BT\n";
        $stream .= "/F1 9 Tf\n";
        $stream .= "1 1 1 rg\n";
        $stream .= ($cardX + 14) . " " . ($sec1Y + 6) . " Td\n";
        $stream .= "(" . self::escapePdfString("1. IDENTITAS KENDARAAN (VEHICLE IDENTITY)") . ") Tj\n";
        $stream .= "ET\n";

        // Section 1 Fields (Two columns)
        $fieldsY = $sec1Y - 20;
        $stream .= "BT\n";
        $stream .= "/F2 8.5 Tf\n";
        $stream .= "0.40 0.45 0.50 rg\n";
        $stream .= ($cardX + 16) . " {$fieldsY} Td\n";
        $stream .= "(" . self::escapePdfString("Nama & Merk:") . ") Tj\n";
        $stream .= "/F1 9 Tf\n";
        $stream .= "0.10 0.15 0.20 rg\n";
        $stream .= "95 0 Td\n";
        $stream .= "(" . self::escapePdfString("{$brand} {$vehicleName}") . ") Tj\n";

        // Plat Nomor
        $stream .= "/F2 8.5 Tf\n";
        $stream .= "0.40 0.45 0.50 rg\n";
        $stream .= "170 0 Td\n";
        $stream .= "(" . self::escapePdfString("Nomor Polisi:") . ") Tj\n";
        $stream .= "/F1 9.5 Tf\n";
        $stream .= "0.04 0.40 0.76 rg\n";
        $stream .= "85 0 Td\n";
        $stream .= "(" . self::escapePdfString($plate) . ") Tj\n";
        $stream .= "ET\n";

        $fieldsY -= 20;
        $stream .= "BT\n";
        $stream .= "/F2 8.5 Tf\n";
        $stream .= "0.40 0.45 0.50 rg\n";
        $stream .= ($cardX + 16) . " {$fieldsY} Td\n";
        $stream .= "(" . self::escapePdfString("Model & Tahun:") . ") Tj\n";
        $stream .= "/F1 9 Tf\n";
        $stream .= "0.10 0.15 0.20 rg\n";
        $stream .= "95 0 Td\n";
        $stream .= "(" . self::escapePdfString("{$model} ({$year})") . ") Tj\n";

        // Odometer
        $stream .= "/F2 8.5 Tf\n";
        $stream .= "0.40 0.45 0.50 rg\n";
        $stream .= "170 0 Td\n";
        $stream .= "(" . self::escapePdfString("Jarak Tempuh:") . ") Tj\n";
        $stream .= "/F1 9 Tf\n";
        $stream .= "0.10 0.15 0.20 rg\n";
        $stream .= "85 0 Td\n";
        $stream .= "(" . self::escapePdfString($mileage) . ") Tj\n";
        $stream .= "ET\n";

        // SECTION 2: DETAIL RIWAYAT SERVIS
        $sec2Y = $fieldsY - 30;
        $stream .= "0.0 0.17 0.29 rg\n";
        $stream .= "{$cardX} {$sec2Y} {$cardW} 22 re f\n";
        $stream .= "BT\n";
        $stream .= "/F1 9 Tf\n";
        $stream .= "1 1 1 rg\n";
        $stream .= ($cardX + 14) . " " . ($sec2Y + 6) . " Td\n";
        $stream .= "(" . self::escapePdfString("2. DETAIL PEKERJAAN SERVIS (SERVICE RECORD DETAILS)") . ") Tj\n";
        $stream .= "ET\n";

        // Section 2 Fields
        $sY = $sec2Y - 20;
        $rows = [
            ['ID Catatan Servis', "#{$svcId}", 'Tanggal Pelaksanaan', $svcDate],
            ['Kategori Servis', $svcType, 'Status Pengerjaan', $status],
            ['Deskripsi Pekerjaan', $svcTitle, 'Biaya Servis', $cost],
            ['Bengkel Pelaksana', $workshop, 'Verifikasi Odometer', $mileage],
        ];

        foreach ($rows as $row) {
            $stream .= "BT\n";
            $stream .= "/F2 8.5 Tf\n";
            $stream .= "0.40 0.45 0.50 rg\n";
            $stream .= ($cardX + 16) . " {$sY} Td\n";
            $stream .= "(" . self::escapePdfString($row[0] . ":") . ") Tj\n";
            $stream .= "/F1 9 Tf\n";
            $stream .= "0.10 0.15 0.20 rg\n";
            $stream .= "95 0 Td\n";
            $stream .= "(" . self::escapePdfString($row[1]) . ") Tj\n";

            $stream .= "/F2 8.5 Tf\n";
            $stream .= "0.40 0.45 0.50 rg\n";
            $stream .= "170 0 Td\n";
            $stream .= "(" . self::escapePdfString($row[2] . ":") . ") Tj\n";
            $stream .= "/F1 9 Tf\n";
            $stream .= ($row[2] === 'Biaya Servis' ? "0.04 0.50 0.25 rg\n" : "0.10 0.15 0.20 rg\n");
            $stream .= "85 0 Td\n";
            $stream .= "(" . self::escapePdfString($row[3]) . ") Tj\n";
            $stream .= "ET\n";
            $sY -= 20;
        }

        // Catatan Servis
        $stream .= "BT\n";
        $stream .= "/F2 8.5 Tf\n";
        $stream .= "0.40 0.45 0.50 rg\n";
        $stream .= ($cardX + 16) . " {$sY} Td\n";
        $stream .= "(" . self::escapePdfString("Catatan Mekanik:") . ") Tj\n";
        $stream .= "/F2 8.5 Tf\n";
        $stream .= "0.20 0.25 0.30 rg\n";
        $stream .= "95 0 Td\n";
        $stream .= "(" . self::escapePdfString(substr($notes, 0, 85)) . ") Tj\n";
        $stream .= "ET\n";

        // SECTION 3: INTEGRITAS HASH CHAIN LOKAL
        $sec3Y = $sY - 30;
        $stream .= "0.0 0.17 0.29 rg\n";
        $stream .= "{$cardX} {$sec3Y} {$cardW} 22 re f\n";
        $stream .= "BT\n";
        $stream .= "/F1 9 Tf\n";
        $stream .= "1 1 1 rg\n";
        $stream .= ($cardX + 14) . " " . ($sec3Y + 6) . " Td\n";
        $stream .= "(" . self::escapePdfString("3. BUKTI INTEGRITAS HASH CHAIN (LOCAL SHA-256 PROOF)") . ") Tj\n";
        $stream .= "ET\n";

        $hY = $sec3Y - 20;
        $stream .= "BT\n";
        $stream .= "/F2 8 Tf\n";
        $stream .= "0.40 0.45 0.50 rg\n";
        $stream .= ($cardX + 16) . " {$hY} Td\n";
        $stream .= "(" . self::escapePdfString("Hash Blok Servis (SHA-256):") . ") Tj\n";
        $stream .= "/F3 8 Tf\n";
        $stream .= "0.10 0.15 0.20 rg\n";
        $stream .= "0 -12 Td\n";
        $stream .= "(" . self::escapePdfString($localHash) . ") Tj\n";

        $stream .= "/F2 8 Tf\n";
        $stream .= "0.40 0.45 0.50 rg\n";
        $stream .= "0 -14 Td\n";
        $stream .= "(" . self::escapePdfString("Hash Blok Sebelumnya (Prev Hash):") . ") Tj\n";
        $stream .= "/F3 8 Tf\n";
        $stream .= "0.35 0.40 0.45 rg\n";
        $stream .= "0 -12 Td\n";
        $stream .= "(" . self::escapePdfString($prevHash) . ") Tj\n";
        $stream .= "ET\n";

        // SECTION 4: VERIFIKASI BLOCKCHAIN & QR CODE
        $sec4Y = $hY - 44;
        $stream .= "0.04 0.40 0.76 rg\n";
        $stream .= "{$cardX} {$sec4Y} {$cardW} 22 re f\n";
        $stream .= "BT\n";
        $stream .= "/F1 9 Tf\n";
        $stream .= "1 1 1 rg\n";
        $stream .= ($cardX + 14) . " " . ($sec4Y + 6) . " Td\n";
        $stream .= "(" . self::escapePdfString("4. VERIFIKASI PUBLIK BLOCKCHAIN & QR CODE VALIDATION") . ") Tj\n";
        $stream .= "ET\n";

        // Instructions next to QR Code
        $textX = $cardX + 16;
        $textY = $sec4Y - 20;
        $stream .= "BT\n";
        $stream .= "/F1 9.5 Tf\n";
        $stream .= "0.0 0.17 0.29 rg\n";
        $stream .= "{$textX} {$textY} Td\n";
        $stream .= "(" . self::escapePdfString("Pindai QR Code untuk Memverifikasi Dokumen Ini") . ") Tj\n";

        $stream .= "/F2 8 Tf\n";
        $stream .= "0.30 0.35 0.40 rg\n";
        $stream .= "0 -14 Td\n";
        $stream .= "(" . self::escapePdfString("Dokumen PDF ini diotentikasi secara kriptografis.") . ") Tj\n";
        $stream .= "0 -11 Td\n";
        $stream .= "(" . self::escapePdfString("Hash SHA-256 dari byte PDF final ini didaftarkan ke jaringan") . ") Tj\n";
        $stream .= "0 -11 Td\n";
        $stream .= "(" . self::escapePdfString("smart contract blockchain publik DriveMate.") . ") Tj\n";

        $stream .= "/F1 8 Tf\n";
        $stream .= "0.04 0.40 0.76 rg\n";
        $stream .= "0 -16 Td\n";
        $stream .= "(" . self::escapePdfString("Tautan Halaman Verifikasi Publik:") . ") Tj\n";
        $stream .= "/F3 7.5 Tf\n";
        $stream .= "0.20 0.25 0.30 rg\n";
        $stream .= "0 -12 Td\n";
        $stream .= "(" . self::escapePdfString(substr($this->verificationUrl, 0, 58)) . ") Tj\n";
        if (strlen($this->verificationUrl) > 58) {
            $stream .= "0 -10 Td\n";
            $stream .= "(" . self::escapePdfString(substr($this->verificationUrl, 58, 58)) . ") Tj\n";
        }
        $stream .= "ET\n";

        // Insert vector QR Code stream
        $stream .= $qrPdfStream;

        // Label under QR Code
        $stream .= "BT\n";
        $stream .= "/F1 7.5 Tf\n";
        $stream .= "0.0 0.17 0.29 rg\n";
        $stream .= ($qrX + 12) . " " . ($qrY - 12) . " Td\n";
        $stream .= "(" . self::escapePdfString("SCAN TO VERIFY") . ") Tj\n";
        $stream .= "ET\n";

        // Footer notice
        $stream .= "BT\n";
        $stream .= "/F2 7 Tf\n";
        $stream .= "0.55 0.60 0.65 rg\n";
        $stream .= ($cardX + 16) . " " . ($cardY + 12) . " Td\n";
        $stream .= "(" . self::escapePdfString("Dokumen ini diterbitkan secara resmi oleh platform DriveMate. Perubahan pada file ini akan membatalkan validitas hash blockchain.") . ") Tj\n";
        $stream .= "ET\n";

        $stream .= "Q\n";

        // 4. Wrap into valid PDF 1.4 document
        return $this->buildPdfDocument($stream, $pageWidth, $pageHeight);
    }

    private function buildPdfDocument(string $contentStream, float $width, float $height): string
    {
        $objects = [];
        $offsets = [];

        // Helper to register an object
        $addObj = function (string $data) use (&$objects, &$offsets): int {
            $id = count($objects) + 1;
            $objects[$id] = $data;
            return $id;
        };

        // 1. Catalog
        $catId = $addObj("<< /Type /Catalog /Pages 2 0 R >>");

        // 2. Pages
        $pagesId = $addObj("<< /Type /Pages /Kids [3 0 R] /Count 1 >>");

        // Font objects
        // 5. Helvetica-Bold
        $f1Id = $addObj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>");
        // 6. Helvetica
        $f2Id = $addObj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");
        // 7. Courier
        $f3Id = $addObj("<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>");

        // 4. Content stream
        $streamLen = strlen($contentStream);
        $streamId = $addObj("<< /Length {$streamLen} >>\nstream\n{$contentStream}\nendstream");

        // 3. Page (referencing fonts and contents)
        $objects[3] = sprintf(
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.2f %.2f] /Contents %d 0 R /Resources << /Font << /F1 %d 0 R /F2 %d 0 R /F3 %d 0 R >> >> >>",
            $width,
            $height,
            $streamId,
            $f1Id,
            $f2Id,
            $f3Id
        );

        // Compile PDF binary with xref
        $out = "%PDF-1.4\n%\xe2\xe3\xcf\xd3\n";

        $numObjs = count($objects);
        for ($i = 1; $i <= $numObjs; $i++) {
            $offsets[$i] = strlen($out);
            $out .= "{$i} 0 obj\n" . $objects[$i] . "\nendobj\n";
        }

        $xrefOffset = strlen($out);
        $out .= "xref\n";
        $out .= "0 " . ($numObjs + 1) . "\n";
        $out .= "0000000000 65535 f \n";
        for ($i = 1; $i <= $numObjs; $i++) {
            $out .= sprintf("%010d 00000 n \n", $offsets[$i]);
        }

        $out .= "trailer\n";
        $out .= "<< /Size " . ($numObjs + 1) . " /Root 1 0 R >>\n";
        $out .= "startxref\n";
        $out .= "{$xrefOffset}\n";
        $out .= "%%EOF\n";

        return $out;
    }
}
