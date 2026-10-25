<?php

// Load .env if present
$loadEnv = function ($filePath) {
    if (!file_exists($filePath) || !is_readable($filePath)) {
        return;
    }
    $lines = file($filePath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if ($lines === false) {
        return;
    }
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#')) {
            continue;
        }
        if (strpos($line, '=') !== false) {
            [$key, $val] = explode('=', $line, 2);
            $key = trim($key);
            $val = trim($val);
            if ((str_starts_with($val, '"') && str_ends_with($val, '"')) ||
                (str_starts_with($val, "'") && str_ends_with($val, "'"))) {
                $val = substr($val, 1, -1);
            }
            if (getenv($key) === false) {
                putenv("{$key}={$val}");
                $_ENV[$key] = $val;
                $_SERVER[$key] = $val;
            }
        }
    }
};

$loadEnv(__DIR__ . '/.env');
$loadEnv(dirname(__DIR__) . '/.env');

return [
    'host' => getenv('DB_HOST') ?: '127.0.0.1',
    'port' => getenv('DB_PORT') ?: '5432',
    'database' => getenv('DB_NAME') ?: 'drivemate_db',
    'username' => getenv('DB_USER') ?: 'postgres',
    'password' => getenv('DB_PASSWORD') !== false ? getenv('DB_PASSWORD') : '',
    'sslmode' => getenv('DB_SSLMODE') ?: 'prefer',

    // LLM AI Config
    'ai_provider' => getenv('AI_PROVIDER') ?: 'gemini',
    'ai_model' => getenv('AI_MODEL') ?: 'gemini-3.8-flash',
    'gemini_api_key' => getenv('GEMINI_API_KEY') ?: (getenv('AI_API_KEY') ?: ''),
    'openai_api_key' => getenv('OPENAI_API_KEY') ?: '',
];
