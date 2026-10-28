
<?php

/**
 * Blockchain Service for DriveMate.
 *
 * Mencatat hash PDF ke DocumentRegistry dan memverifikasi
 * hash melalui smart contract.
 *
 * Dependensi:
 * composer require web3p/ethereum-tx:^0.4.3
 * composer require kornrunner/keccak:^1.1
 */

$composerAutoload = __DIR__ . '/vendor/autoload.php';

if (is_file($composerAutoload)) {
    require_once $composerAutoload;
}

class BlockchainService
{
    private string $rpcUrl;
    private string $contractAddress;
    private string $privateKey;
    private string $networkName;
    private int $timeoutSeconds;

    public function __construct(array $config = [])
    {
        $this->rpcUrl = trim((string) ($config['blockchain_rpc_url'] ?? ''));
        $this->contractAddress = trim((string) ($config['blockchain_contract_address'] ?? ''));
        $this->privateKey = trim((string) ($config['blockchain_private_key'] ?? ''));
        $this->networkName = trim((string) ($config['blockchain_network_name'] ?? 'Polygon Amoy Testnet'));
        $this->timeoutSeconds = max(2, (int) ($config['timeout'] ?? 8));
    }

    public function isConfigured(): bool
    {
        return $this->rpcUrl !== ''
            && preg_match('/^0x[a-fA-F0-9]{40}$/', $this->contractAddress) === 1;
    }

    public function getNetworkName(): string
    {
        return $this->networkName;
    }

    public function getContractAddress(): string
    {
        return $this->contractAddress;
    }

    private function result(
        string $status,
        ?string $txHash,
        string $message,
        ?string $onChainHash = null
    ): array {
        return [
            'status' => $status,
            'transaction_hash' => $txHash,
            'network_name' => $this->networkName,
            'contract_address' => $this->contractAddress !== ''
                ? $this->contractAddress
                : null,
            'on_chain_hash' => $onChainHash,
            'message' => $message,
        ];
    }

    private function validateHash(string $hash): string
    {
        $hash = preg_replace('/^0x/i', '', trim($hash));

        if (!is_string($hash) || preg_match('/^[a-fA-F0-9]{64}$/', $hash) !== 1) {
            throw new InvalidArgumentException(
                'Hash dokumen harus berupa 64 karakter heksadesimal SHA-256.'
            );
        }

        return strtolower($hash);
    }

    private function encodeWord(string $hex): string
    {
        if (strlen($hex) > 64 || preg_match('/^[a-fA-F0-9]*$/', $hex) !== 1) {
            throw new InvalidArgumentException('Nilai ABI tidak valid.');
        }

        return str_pad(strtolower($hex), 64, '0', STR_PAD_LEFT);
    }

    private function encodeString(string $value): string
    {
        $hex = bin2hex($value);
        $length = strlen($hex) / 2;
        $paddedLength = (int) (ceil($length / 32) * 64);

        return $this->encodeWord(dechex($length))
            . str_pad($hex, $paddedLength, '0', STR_PAD_RIGHT);
    }

    private function encodeCall(string $signature, array $words): string
    {
        $selector = substr(self::keccak256($signature), 0, 8);

        return '0x' . $selector . implode('', $words);
    }

    private function encodeRecordCall(
        string $documentId,
        string $hash,
        int $serviceRecordId
    ): string {
        if ($documentId === '' || $serviceRecordId < 0) {
            throw new InvalidArgumentException('Data dokumen tidak valid.');
        }

        $dynamicOffset = $this->encodeWord('60');

        return $this->encodeCall(
            'recordDocument(string,bytes32,uint256)',
            [
                $dynamicOffset,
                $hash,
                $this->encodeWord(dechex($serviceRecordId)),
            ]
        ) . substr($this->encodeString($documentId), 0);
    }

    private function encodeStringCall(string $signature, string $value): string
    {
        return $this->encodeCall($signature, [
            $this->encodeWord('20'),
        ]) . substr($this->encodeString($value), 0);
    }

    private function rpcCall(string $method, array $params)
    {
        if ($this->rpcUrl === '') {
            throw new RuntimeException('URL RPC belum dikonfigurasi.');
        }

        $payload = json_encode([
            'jsonrpc' => '2.0',
            'id' => 1,
            'method' => $method,
            'params' => $params,
        ]);

        if (!is_string($payload)) {
            throw new RuntimeException('Gagal membuat payload JSON-RPC.');
        }

        $ch = curl_init($this->rpcUrl);

        if ($ch === false) {
            throw new RuntimeException('Gagal menginisialisasi koneksi RPC.');
        }

        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $payload,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
            CURLOPT_TIMEOUT => $this->timeoutSeconds,
            CURLOPT_CONNECTTIMEOUT => 4,
        ]);

        $response = curl_exec($ch);
        $error = curl_error($ch);
        $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($response === false || $error !== '') {
            throw new RuntimeException('Koneksi RPC gagal: ' . $error);
        }

        if ($httpCode < 200 || $httpCode >= 300) {
            throw new RuntimeException('RPC mengembalikan HTTP ' . $httpCode . '.');
        }

        $json = json_decode((string) $response, true);

        if (!is_array($json)) {
            throw new RuntimeException('Respons JSON-RPC tidak valid.');
        }

        if (isset($json['error'])) {
            $message = $json['error']['message'] ?? 'Kesalahan RPC tidak diketahui.';
            throw new RuntimeException('JSON-RPC: ' . $message);
        }

        if (!array_key_exists('result', $json)) {
            throw new RuntimeException('Respons RPC tidak memiliki result.');
        }

        return $json['result'];
    }

    /**
     * Mencatat hash dokumen ke smart contract.
     */
    public function recordDocument(
        string $documentId,
        string $documentHash,
        int $serviceRecordId
    ): array {
        $txHash = null;

        try {
            $hash = $this->validateHash($documentHash);

            if ($documentId === '' || $serviceRecordId < 0) {
                throw new InvalidArgumentException('Identitas dokumen tidak valid.');
            }

            if (!$this->isConfigured()) {
                return $this->result(
                    'pending',
                    null,
                    'RPC atau alamat smart contract belum dikonfigurasi.'
                );
            }

            if ($this->privateKey === '') {
                return $this->result(
                    'pending',
                    null,
                    'Private key signer belum dikonfigurasi.'
                );
            }

            if (!class_exists(\Web3p\EthereumTx\Transaction::class)) {
                return $this->result(
                    'failed',
                    null,
                    'Dependensi web3p/ethereum-tx belum terpasang.'
                );
            }

            if (!class_exists(\Elliptic\EC::class)
                || !class_exists(\kornrunner\Keccak::class)
            ) {
                return $this->result(
                    'failed',
                    null,
                    'Dependensi kriptografi belum tersedia.'
                );
            }

            $chainIdHex = $this->rpcCall('eth_chainId', []);
            $chainId = hexdec((string) $chainIdHex);

            if ($chainId <= 0) {
                throw new RuntimeException('Chain ID RPC tidak valid.');
            }

            $signerAddress = $this->derivePublicAddress();

            $nonceHex = $this->rpcCall('eth_getTransactionCount', [
                $signerAddress,
                'pending',
            ]);

            $gasPriceHex = $this->rpcCall('eth_gasPrice', []);

            $data = $this->encodeRecordCall(
                $documentId,
                $hash,
                $serviceRecordId
            );

            $gasHex = $this->rpcCall('eth_estimateGas', [[
                'from' => $signerAddress,
                'to' => $this->contractAddress,
                'data' => $data,
            ]]);

            $tx = [
                'nonce' => $nonceHex,
                'gasPrice' => $gasPriceHex,
                'gasLimit' => $gasHex,
                'to' => $this->contractAddress,
                'value' => '0x0',
                'data' => $data,
                'chainId' => $chainId,
            ];

            $transaction = new \Web3p\EthereumTx\Transaction($tx);
            $signed = $transaction->sign($this->privateKey);

            $txHash = $this->rpcCall('eth_sendRawTransaction', [
                '0x' . $signed,
            ]);

            if (!is_string($txHash)
                || preg_match('/^0x[a-fA-F0-9]{64}$/', $txHash) !== 1
            ) {
                return $this->result(
                    'failed',
                    null,
                    'RPC tidak mengembalikan transaction hash yang valid.'
                );
            }

            $receipt = $this->rpcCall('eth_getTransactionReceipt', [$txHash]);

            if (!is_array($receipt) || !isset($receipt['status'])) {
                return $this->result(
                    'pending',
                    $txHash,
                    'Transaksi terkirim; receipt belum tersedia.'
                );
            }

            if (strtolower((string) $receipt['status']) !== '0x1') {
                return $this->result(
                    'failed',
                    $txHash,
                    'Transaksi gagal atau di-revert oleh EVM.'
                );
            }

            $verification = $this->verifyDocumentOnChain($documentId, $hash);

            if (($verification['is_valid'] ?? false) === true) {
                return $this->result(
                    'verified',
                    $txHash,
                    'Hash PDF cocok dengan catatan smart contract.',
                    $verification['on_chain_hash'] ?? null
                );
            }

            return $this->result(
                'unconfirmed',
                $txHash,
                'Transaksi berhasil, tetapi hash belum dapat dikonfirmasi melalui smart contract.',
                $verification['on_chain_hash'] ?? null
            );
        } catch (InvalidArgumentException $e) {
            return $this->result('failed', $txHash, $e->getMessage());
        } catch (Throwable $e) {
            error_log('Blockchain recordDocument error: ' . $e->getMessage());

            return $this->result(
                'failed',
                $txHash,
                'Proses pencatatan blockchain gagal. Periksa konfigurasi dan log backend.'
            );
        }
    }

    /**
     * Membandingkan hash dokumen dengan catatan pada smart contract.
     */
    public function verifyDocumentOnChain(
        string $documentId,
        string $expectedHash
    ): array {
        try {
            $hash = $this->validateHash($expectedHash);

            if (!$this->isConfigured()) {
                return [
                    'status' => 'unconfigured',
                    'is_valid' => false,
                    'network_name' => $this->networkName,
                    'contract_address' => $this->contractAddress ?: null,
                    'on_chain_hash' => null,
                    'message' => 'Smart contract belum dikonfigurasi.',
                ];
            }

            if ($documentId === '') {
                throw new InvalidArgumentException('Document ID tidak boleh kosong.');
            }

            $data = $this->encodeStringCall('getDocument(string)', $documentId);

            $rawResult = $this->rpcCall('eth_call', [[
                'to' => $this->contractAddress,
                'data' => $data,
            ], 'latest']);

            if (!is_string($rawResult)
                || !preg_match('/^0x[0-9a-fA-F]+$/', $rawResult)
            ) {
                return [
                    'status' => 'not_found_on_chain',
                    'is_valid' => false,
                    'network_name' => $this->networkName,
                    'contract_address' => $this->contractAddress,
                    'on_chain_hash' => null,
                    'message' => 'Dokumen belum ditemukan atau respons kontrak kosong.',
                ];
            }

            $raw = substr($rawResult, 2);

            // Enam ABI head words ditambah minimal satu length word.
            if (strlen($raw) < 64 * 7) {
                return [
                    'status' => 'unconfirmed',
                    'is_valid' => false,
                    'network_name' => $this->networkName,
                    'contract_address' => $this->contractAddress,
                    'on_chain_hash' => null,
                    'message' => 'Data balasan kontrak terlalu pendek atau tidak valid.',
                ];
            }

            $idOffset = hexdec(substr($raw, 0, 64));
            $onChainHash = strtolower(substr($raw, 64, 64));
            $registeredAt = hexdec(substr($raw, 192, 64));
            $recordedBy = '0x' . substr($raw, 256 + 24, 40);
            $isRegistered = hexdec(substr($raw, 320, 64)) === 1;

            $idStart = (int) $idOffset * 2;

            if ($idStart < 0 || strlen($raw) < $idStart + 64) {
                return [
                    'status' => 'unconfirmed',
                    'is_valid' => false,
                    'network_name' => $this->networkName,
                    'contract_address' => $this->contractAddress,
                    'on_chain_hash' => null,
                    'message' => 'Offset ID pada respons kontrak tidak valid.',
                ];
            }

            $idLength = hexdec(substr($raw, $idStart, 64));

            if ($idLength < 0
                || strlen($raw) < $idStart + 64 + ($idLength * 2)
            ) {
                return [
                    'status' => 'unconfirmed',
                    'is_valid' => false,
                    'network_name' => $this->networkName,
                    'contract_address' => $this->contractAddress,
                    'on_chain_hash' => null,
                    'message' => 'Panjang ID pada respons kontrak tidak valid.',
                ];
            }

            $idHex = substr($raw, $idStart + 64, $idLength * 2);
            $returnedId = hex2bin($idHex);

            if (!is_string($returnedId) || $returnedId !== $documentId) {
                $isRegistered = false;
            }

            if (!$isRegistered || $onChainHash === str_repeat('0', 64)) {
                return [
                    'status' => 'not_found_on_chain',
                    'is_valid' => false,
                    'network_name' => $this->networkName,
                    'contract_address' => $this->contractAddress,
                    'on_chain_hash' => null,
                    'message' => 'Dokumen belum terdaftar pada smart contract.',
                ];
            }

            $valid = hash_equals($hash, $onChainHash);

            return [
                'status' => $valid ? 'verified' : 'mismatch',
                'is_valid' => $valid,
                'network_name' => $this->networkName,
                'contract_address' => $this->contractAddress,
                'on_chain_hash' => $onChainHash,
                'registered_at' => $registeredAt,
                'recorded_by' => $recordedBy,
                'message' => $valid
                    ? 'Hash PDF cocok dengan catatan smart contract.'
                    : 'Hash PDF tidak cocok dengan catatan smart contract.',
            ];
        } catch (InvalidArgumentException $e) {
            return [
                'status' => 'invalid_input',
                'is_valid' => false,
                'network_name' => $this->networkName,
                'contract_address' => $this->contractAddress ?: null,
                'on_chain_hash' => null,
                'message' => $e->getMessage(),
            ];
        } catch (Throwable $e) {
            error_log('Blockchain verifyDocument error: ' . $e->getMessage());

            return [
                'status' => 'network_error',
                'is_valid' => false,
                'network_name' => $this->networkName,
                'contract_address' => $this->contractAddress ?: null,
                'on_chain_hash' => null,
                'message' => 'Verifikasi blockchain tidak dapat diselesaikan.',
            ];
        }
    }

    /**
     * Menurunkan alamat Ethereum dari private key.
     */
    private function derivePublicAddress(): string
    {
        if ($this->privateKey === '') {
            throw new RuntimeException('Private key belum dikonfigurasi.');
        }

        if (!class_exists(\Elliptic\EC::class)) {
            throw new RuntimeException(
                'Dependensi elliptic belum tersedia untuk menurunkan alamat signer.'
            );
        }

        $key = preg_replace('/^0x/i', '', $this->privateKey);

        if (!is_string($key) || preg_match('/^[a-fA-F0-9]{64}$/', $key) !== 1) {
            throw new RuntimeException('Format private key tidak valid.');
        }

        $ec = new \Elliptic\EC('secp256k1');
        $keyPair = $ec->keyFromPrivate($key);
        $publicKey = $keyPair->getPublic(false, 'hex');

        $publicKey = substr($publicKey, 2);
        $publicKeyBytes = hex2bin($publicKey);

        if (!is_string($publicKeyBytes)) {
            throw new RuntimeException('Gagal menurunkan public key signer.');
        }

        $address = substr(self::keccak256($publicKeyBytes), -40);

        return '0x' . $address;
    }

    public static function keccak256(string $data): string
    {
        if (function_exists('keccak256')) {
            return strtolower((string) keccak256($data));
        }

        if (class_exists(\kornrunner\Keccak::class)) {
            return strtolower(\kornrunner\Keccak::hash($data, 256));
        }

        throw new RuntimeException(
            'Implementasi Keccak-256 tidak tersedia. Pasang library yang kompatibel.'
        );
    }
}
