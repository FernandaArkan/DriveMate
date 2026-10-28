<?php

// Load .env if present.
// Environment variables configured by hosting take priority.
$loadEnv = function ($filePath) {
    if (!file_exists($filePath) || !is_readable($filePath)) {
        return;
    }

    $lines = file(
        $filePath,
        FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES
    );

    if ($lines === false) {
        return;
    }

    foreach ($lines as $line) {
        $line = trim($line);

        if ($line === '' || str_starts_with($line, '#')) {
            continue;
        }

        if (strpos($line, '=') === false) {
            continue;
        }

        [$key, $val] = explode('=', $line, 2);
        $key = trim($key);
        $val = trim($val);

        if (
            (str_starts_with($val, '"') && str_ends_with($val, '"')) ||
            (str_starts_with($val, "'") && str_ends_with($val, "'"))
        ) {
            $val = substr($val, 1, -1);
        }

        // Do not override variables provided by hosting.
        if (getenv($key) === false) {
            putenv("{$key}={$val}");
            $_ENV[$key] = $val;
            $_SERVER[$key] = $val;
        }
    }
};

$loadEnv(__DIR__ . '/.env');
$loadEnv(dirname(__DIR__) . '/.env');

// Read environment variables with fallback sources.
$getEnv = function ($key, $default = '') {
    $value = getenv($key);

    if ($value !== false && $value !== '') {
        return $value;
    }

    if (isset($_ENV[$key]) && $_ENV[$key] !== '') {
        return $_ENV[$key];
    }

    if (isset($_SERVER[$key]) && $_SERVER[$key] !== '') {
        return $_SERVER[$key];
    }

    return $default;
};

return [
    // PostgreSQL configuration.
    'host' => $getEnv('DB_HOST', '127.0.0.1'),
    'port' => $getEnv('DB_PORT', '5432'),
    'database' => $getEnv('DB_NAME', 'drivemate_db'),
    'username' => $getEnv('DB_USER', 'postgres'),
    'password' => $getEnv('DB_PASSWORD'),
    'sslmode' => $getEnv('DB_SSLMODE', 'prefer'),

    // Groq AI configuration.
    'ai_provider' => $getEnv('AI_PROVIDER', 'groq'),
    'ai_model' => $getEnv(
        'AI_MODEL',
        'openai/gpt-oss-120b'
    ),
    'groq_api_key' => $getEnv('GROQ_API_KEY'),

    // Retain compatibility with other AI providers.
    'gemini_api_key' => $getEnv('GEMINI_API_KEY')
        ?: $getEnv('AI_API_KEY'),
    'openai_api_key' => $getEnv('OPENAI_API_KEY'),

    // Blockchain & Smart Contract configuration.
    'blockchain_rpc_url' => $getEnv('BLOCKCHAIN_RPC_URL', ''),
    'blockchain_contract_address' => $getEnv('BLOCKCHAIN_CONTRACT_ADDRESS', ''),
    'blockchain_private_key' => $getEnv('BLOCKCHAIN_PRIVATE_KEY', ''),
    'blockchain_network_name' => $getEnv('BLOCKCHAIN_NETWORK_NAME', 'Polygon Amoy Testnet'),

    // App Base URL for QR codes and verification links.
    'app_base_url' => $getEnv(
        'APP_BASE_URL',
        'https://drivemate-3c397.containers.snapdeploy.app'
    ),
];
