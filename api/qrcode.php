<?php

/**
 * Pure PHP QR Code Generator
 * Generates ISO/IEC 18004 compliant QR Codes in pure PHP with ZERO dependencies.
 * Supports matrix extraction, SVG output, and native PDF vector graphic stream.
 */
class QRCode
{
    public const EC_L = 1; // 7% recovery
    public const EC_M = 0; // 15% recovery
    public const EC_Q = 3; // 25% recovery
    public const EC_H = 2; // 30% recovery

    // Mode indicator for 8-bit byte data
    private const MODE_BYTE = 0b0100;

    /**
     * Capacity table for Byte mode (Version 1..10, EC_L / EC_M)
     * Format: [version => ['L' => maxBytes, 'M' => maxBytes, 'totalCodewords', 'ecCodewordsPerBlock', 'numBlocks']]
     */
    private static array $VERSIONS = [
        1  => ['L' => 17,  'M' => 14,  'total' => 26,   'ec' => 7,  'blocks' => 1],
        2  => ['L' => 32,  'M' => 26,  'total' => 44,   'ec' => 10, 'blocks' => 1],
        3  => ['L' => 53,  'M' => 42,  'total' => 70,   'ec' => 15, 'blocks' => 1],
        4  => ['L' => 78,  'M' => 62,  'total' => 100,  'ec' => 20, 'blocks' => 1],
        5  => ['L' => 106, 'M' => 84,  'total' => 134,  'ec' => 26, 'blocks' => 1],
        6  => ['L' => 134, 'M' => 106, 'total' => 172,  'ec' => 18, 'blocks' => 2],
        7  => ['L' => 154, 'M' => 122, 'total' => 196,  'ec' => 20, 'blocks' => 2],
        8  => ['L' => 192, 'M' => 152, 'total' => 242,  'ec' => 24, 'blocks' => 2],
        9  => ['L' => 230, 'M' => 180, 'total' => 292,  'ec' => 30, 'blocks' => 2],
        10 => ['L' => 271, 'M' => 213, 'total' => 346,  'ec' => 18, 'blocks' => 4],
    ];

    private static array $ALIGNMENT_PATTERNS = [
        1 => [],
        2 => [6, 18],
        3 => [6, 22],
        4 => [6, 26],
        5 => [6, 30],
        6 => [6, 34],
        7 => [6, 22, 38],
        8 => [6, 24, 42],
        9 => [6, 26, 46],
        10=> [6, 28, 50],
    ];

    private string $data;
    private int $ecLevel;
    private int $version;
    private int $size;
    private array $modules = [];
    private array $isFunction = [];

    public function __construct(string $data, int $ecLevel = self::EC_M)
    {
        $this->data = $data;
        $this->ecLevel = $ecLevel;
        $this->version = $this->determineVersion(strlen($data), $ecLevel);
        $this->size = 17 + 4 * $this->version;
        $this->buildMatrix();
    }

    public static function create(string $data, int $ecLevel = self::EC_M): self
    {
        return new self($data, $ecLevel);
    }

    public function getMatrix(): array
    {
        return $this->modules;
    }

    public function getSize(): int
    {
        return $this->size;
    }

    private function determineVersion(int $length, int $ecLevel): int
    {
        $ecKey = ($ecLevel === self::EC_L) ? 'L' : 'M';
        foreach (self::$VERSIONS as $ver => $info) {
            if ($length <= $info[$ecKey]) {
                return $ver;
            }
        }
        return 10;
    }

    private function buildMatrix(): void
    {
        for ($r = 0; $r < $this->size; $r++) {
            $this->modules[$r] = array_fill(0, $this->size, false);
            $this->isFunction[$r] = array_fill(0, $this->size, false);
        }

        // 1. Finder patterns at (0,0), (0, size-7), (size-7, 0)
        $this->placeFinder(0, 0);
        $this->placeFinder($this->size - 7, 0);
        $this->placeFinder(0, $this->size - 7);

        // 2. Alignment patterns
        $coords = self::$ALIGNMENT_PATTERNS[$this->version];
        $count = count($coords);
        for ($i = 0; $i < $count; $i++) {
            for ($j = 0; $j < $count; $j++) {
                $r = $coords[$i];
                $c = $coords[$j];
                // Do not overlap with finder patterns
                if (($r <= 8 && $c <= 8) || ($r <= 8 && $c >= $this->size - 8) || ($r >= $this->size - 8 && $c <= 8)) {
                    continue;
                }
                $this->placeAlignment($r, $c);
            }
        }

        // 3. Timing patterns
        for ($i = 8; $i < $this->size - 8; $i++) {
            $val = ($i % 2 === 0);
            $this->setFunction(6, $i, $val);
            $this->setFunction($i, 6, $val);
        }

        // 4. Dark module
        $this->setFunction(4 * $this->version + 9, 8, true);

        // 5. Reserve format info areas
        $this->reserveFormatAreas();

        // 6. Encode data & error correction
        $codewords = $this->encodeData();

        // 7. Place data bits
        $this->placeData($codewords);

        // 8. Masking (use standard mask pattern 0: (row + col) % 2 == 0)
        $this->applyMask(0);

        // 9. Write format info with mask 0
        $this->writeFormatInfo(0);
    }

    private function setFunction(int $r, int $c, bool $val): void
    {
        $this->modules[$r][$c] = $val;
        $this->isFunction[$r][$c] = true;
    }

    private function placeFinder(int $row, int $col): void
    {
        for ($r = -1; $r <= 7; $r++) {
            for ($c = -1; $c <= 7; $c++) {
                $nr = $row + $r;
                $nc = $col + $c;
                if ($nr >= 0 && $nr < $this->size && $nc >= 0 && $nc < $this->size) {
                    $isDark = ($r >= 0 && $r <= 6 && ($c === 0 || $c === 6)) ||
                              ($c >= 0 && $c <= 6 && ($r === 0 || $r === 6)) ||
                              ($r >= 2 && $r <= 4 && $c >= 2 && $c <= 4);
                    $this->setFunction($nr, $nc, $isDark);
                }
            }
        }
    }

    private function placeAlignment(int $row, int $col): void
    {
        for ($r = -2; $r <= 2; $r++) {
            for ($c = -2; $c <= 2; $c++) {
                $isDark = (abs($r) === 2 || abs($c) === 2 || ($r === 0 && $c === 0));
                $this->setFunction($row + $r, $col + $c, $isDark);
            }
        }
    }

    private function reserveFormatAreas(): void
    {
        for ($i = 0; $i <= 8; $i++) {
            $this->isFunction[8][$i] = true;
            $this->isFunction[$i][8] = true;
        }
        for ($i = $this->size - 8; $i < $this->size; $i++) {
            $this->isFunction[8][$i] = true;
            $this->isFunction[$i][8] = true;
        }
    }

    private function encodeData(): array
    {
        $info = self::$VERSIONS[$this->version];
        $totalCodewords = $info['total'];
        $ecCodewords = $info['ec'];
        $numBlocks = $info['blocks'];
        $dataCodewordsCount = $totalCodewords - ($ecCodewords * $numBlocks);

        // Bit stream: Mode (4 bits) + Count (8 bits for V1-9) + Data
        $bits = [];
        $this->appendBits($bits, self::MODE_BYTE, 4);
        $this->appendBits($bits, strlen($this->data), 8);

        for ($i = 0; $i < strlen($this->data); $i++) {
            $this->appendBits($bits, ord($this->data[$i]), 8);
        }

        // Terminator (up to 4 zeros)
        $capacityBits = $dataCodewordsCount * 8;
        $terminatorLen = min(4, $capacityBits - count($bits));
        for ($i = 0; $i < $terminatorLen; $i++) {
            $bits[] = 0;
        }

        // Pad to 8-bit boundary
        while (count($bits) % 8 !== 0) {
            $bits[] = 0;
        }

        // Convert bits to data codewords
        $dataCodewords = [];
        for ($i = 0; $i < count($bits); $i += 8) {
            $byte = 0;
            for ($b = 0; $b < 8; $b++) {
                $byte = ($byte << 1) | $bits[$i + $b];
            }
            $dataCodewords[] = $byte;
        }

        // Pad with alternating 0xEC and 0x11
        $padBytes = [0xEC, 0x11];
        $padIdx = 0;
        while (count($dataCodewords) < $dataCodewordsCount) {
            $dataCodewords[] = $padBytes[$padIdx];
            $padIdx ^= 1;
        }

        // Reed-Solomon Error Correction
        $blocks = [];
        $ecBlocks = [];
        $baseDataLen = (int) floor($dataCodewordsCount / $numBlocks);
        $extraDataBlocks = $dataCodewordsCount % $numBlocks;

        $offset = 0;
        for ($b = 0; $b < $numBlocks; $b++) {
            $len = $baseDataLen + ($b >= ($numBlocks - $extraDataBlocks) ? 1 : 0);
            $blockData = array_slice($dataCodewords, $offset, $len);
            $offset += $len;
            $blocks[] = $blockData;
            $ecBlocks[] = $this->calculateReedSolomon($blockData, $ecCodewords);
        }

        // Interleave data codewords
        $finalCodewords = [];
        $maxDataLen = $baseDataLen + ($extraDataBlocks > 0 ? 1 : 0);
        for ($i = 0; $i < $maxDataLen; $i++) {
            for ($b = 0; $b < $numBlocks; $b++) {
                if ($i < count($blocks[$b])) {
                    $finalCodewords[] = $blocks[$b][$i];
                }
            }
        }

        // Interleave EC codewords
        for ($i = 0; $i < $ecCodewords; $i++) {
            for ($b = 0; $b < $numBlocks; $b++) {
                $finalCodewords[] = $ecBlocks[$b][$i];
            }
        }

        return $finalCodewords;
    }

    private function appendBits(array &$bits, int $val, int $len): void
    {
        for ($i = $len - 1; $i >= 0; $i--) {
            $bits[] = ($val >> $i) & 1;
        }
    }

    private function calculateReedSolomon(array $data, int $ecCount): array
    {
        // Galois Field GF(256) tables
        static $gfExp = null, $gfLog = null;
        if ($gfExp === null) {
            $gfExp = array_fill(0, 512, 0);
            $gfLog = array_fill(0, 256, 0);
            $x = 1;
            for ($i = 0; $i < 255; $i++) {
                $gfExp[$i] = $x;
                $gfLog[$x] = $i;
                $x <<= 1;
                if ($x & 0x100) {
                    $x ^= 0x11D;
                }
            }
            for ($i = 255; $i < 512; $i++) {
                $gfExp[$i] = $gfExp[$i - 255];
            }
        }

        // Generator polynomial for ecCount
        $generator = [1];
        for ($i = 0; $i < $ecCount; $i++) {
            $next = array_fill(0, count($generator) + 1, 0);
            $factor = $gfExp[$i];
            for ($j = 0; $j < count($generator); $j++) {
                $next[$j] ^= $generator[$j];
                $val = ($generator[$j] === 0) ? 0 : $gfExp[$gfLog[$generator[$j]] + $gfLog[$factor]];
                $next[$j + 1] ^= $val;
            }
            $generator = $next;
        }

        // Polynomial division
        $remainder = array_fill(0, $ecCount, 0);
        $padded = array_merge($data, array_fill(0, $ecCount, 0));

        for ($i = 0; $i < count($data); $i++) {
            $lead = $padded[$i];
            if ($lead !== 0) {
                $logLead = $gfLog[$lead];
                for ($j = 0; $j < count($generator); $j++) {
                    if ($generator[$j] !== 0) {
                        $padded[$i + $j] ^= $gfExp[$logLead + $gfLog[$generator[$j]]];
                    }
                }
            }
        }

        return array_slice($padded, count($data), $ecCount);
    }

    private function placeData(array $codewords): void
    {
        $bits = [];
        foreach ($codewords as $cw) {
            for ($i = 7; $i >= 0; $i--) {
                $bits[] = ($cw >> $i) & 1;
            }
        }

        $bitIdx = 0;
        $totalBits = count($bits);
        $up = true;

        for ($right = $this->size - 1; $right > 0; $right -= 2) {
            if ($right === 6) {
                $right--; // Skip vertical timing column
            }
            $rows = $up ? range($this->size - 1, 0, -1) : range(0, $this->size - 1);
            foreach ($rows as $r) {
                for ($c = $right; $c >= $right - 1; $c--) {
                    if (!$this->isFunction[$r][$c]) {
                        $this->modules[$r][$c] = ($bitIdx < $totalBits) ? ($bits[$bitIdx] === 1) : false;
                        $bitIdx++;
                    }
                }
            }
            $up = !$up;
        }
    }

    private function applyMask(int $mask): void
    {
        for ($r = 0; $r < $this->size; $r++) {
            for ($c = 0; $c < $this->size; $c++) {
                if (!$this->isFunction[$r][$c]) {
                    // Pattern 0: (r + c) % 2 === 0
                    if (($r + $c) % 2 === 0) {
                        $this->modules[$r][$c] = !$this->modules[$r][$c];
                    }
                }
            }
        }
    }

    private function writeFormatInfo(int $mask): void
    {
        // EC_M = 0 (00), Mask 0 = 0 (000) => 5 bits = 00000
        // BCH error correction code for format info:
        // Format bits = (ecBits << 3) | mask
        $formatData = (($this->ecLevel & 3) << 3) | ($mask & 7);
        $rem = $formatData << 10;
        $gen = 0x537;
        for ($i = 14; $i >= 10; $i--) {
            if ($rem & (1 << $i)) {
                $rem ^= ($gen << ($i - 10));
            }
        }
        $formatBits = (($formatData << 10) | $rem) ^ 0x5412;

        // Place around top-left finder
        for ($i = 0; $i <= 5; $i++) {
            $this->modules[8][$i] = (($formatBits >> $i) & 1) === 1;
        }
        $this->modules[8][7] = (($formatBits >> 6) & 1) === 1;
        $this->modules[8][8] = (($formatBits >> 7) & 1) === 1;
        $this->modules[7][8] = (($formatBits >> 8) & 1) === 1;
        for ($i = 9; $i <= 14; $i++) {
            $this->modules[14 - $i][8] = (($formatBits >> $i) & 1) === 1;
        }

        // Place around other finders
        for ($i = 0; $i <= 7; $i++) {
            $this->modules[$this->size - 1 - $i][8] = (($formatBits >> $i) & 1) === 1;
        }
        for ($i = 8; $i <= 14; $i++) {
            $this->modules[8][$this->size - 15 + $i] = (($formatBits >> $i) & 1) === 1;
        }
    }

    /**
     * Render as clean SVG image string.
     */
    public function toSvg(int $pixelSize = 200, string $darkColor = '#002B49', string $lightColor = '#FFFFFF'): string
    {
        $scale = $pixelSize / $this->size;
        $svg = sprintf(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">',
            $this->size,
            $this->size,
            $pixelSize,
            $pixelSize
        );
        $svg .= sprintf('<rect width="%d" height="%d" fill="%s"/>', $this->size, $this->size, htmlspecialchars($lightColor));
        $svg .= sprintf('<path fill="%s" d="', htmlspecialchars($darkColor));

        $d = '';
        for ($r = 0; $r < $this->size; $r++) {
            for ($c = 0; $c < $this->size; $c++) {
                if ($this->modules[$r][$c]) {
                    $d .= sprintf('M%d,%dh1v1h-1z ', $c, $r);
                }
            }
        }
        $svg .= trim($d) . '"/></svg>';
        return $svg;
    }

    /**
     * Render as native PDF vector stream operators.
     * Generates rectangle paths (x y w h re f) for zero-dependency vector PDF embedding.
     *
     * @param float $x X coordinate in PDF points
     * @param float $y Y coordinate in PDF points (bottom of QR code)
     * @param float $size Width and height in points
     * @return string PDF operator string
     */
    public function renderPdfStream(float $x, float $y, float $size): string
    {
        $cellSize = $size / $this->size;
        $ops = "q\n";
        // White background box
        $ops .= "1 1 1 rg\n";
        $ops .= sprintf("%.2f %.2f %.2f %.2f re f\n", $x, $y, $size, $size);

        // Dark color modules
        $ops .= "0 0.17 0.29 rg\n"; // DriveMate Navy #002B49
        for ($r = 0; $r < $this->size; $r++) {
            for ($c = 0; $c < $this->size; $c++) {
                if ($this->modules[$r][$c]) {
                    // PDF coordinates: Y increases upwards, so row 0 is at top: (y + size - (r+1)*cell)
                    $cellX = $x + ($c * $cellSize);
                    $cellY = $y + $size - (($r + 1) * $cellSize);
                    $ops .= sprintf("%.2f %.2f %.2f %.2f re f\n", $cellX, $cellY, $cellSize, $cellSize);
                }
            }
        }
        $ops .= "Q\n";
        return $ops;
    }
}
