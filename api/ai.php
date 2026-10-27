<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Method not allowed. Use POST.',
        'reply' => null
    ]);
    exit;
}

$startTime = microtime(true);

function respond($statusCode, array $data)
{
    http_response_code($statusCode);
    echo json_encode(
        $data,
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
    );
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

if (!is_array($input)) {
    respond(400, [
        'success' => false,
        'message' => 'Invalid JSON request body.',
        'reply' => null
    ]);
}

$message = trim((string) ($input['message'] ?? ''));
$history = $input['history'] ?? [];

if ($message === '') {
    respond(400, [
        'success' => false,
        'message' => 'Message cannot be empty.',
        'reply' => null
    ]);
}

if (!is_array($history)) {
    $history = [];
}

$config = require __DIR__ . '/config.php';

$provider = $config['ai_provider'] ?? 'groq';
$model = $config['ai_model'] ?? 'openai/gpt-oss-120b';
$apiKey = $config['groq_api_key'] ?? '';

if ($provider !== 'groq') {
    respond(500, [
        'success' => false,
        'message' => 'Unsupported AI provider.',
        'reply' => null
    ]);
}

if ($apiKey === '') {
    respond(500, [
        'success' => false,
        'message' => 'Groq API key is not configured on the server.',
        'reply' => null
    ]);
}

$messages = [
    [
        'role' => 'system',
        'content' =>
            'Kamu adalah DriveMate AI, asisten yang membantu pengguna ' .
            'memahami masalah dan perawatan kendaraan bermotor. ' .
            'Jawab dalam bahasa Indonesia dengan jelas, praktis, dan aman. ' .
            'Utamakan topik kendaraan, perawatan, diagnosis awal, dan ' .
            'keselamatan berkendara. Jika masalah berpotensi membahayakan, ' .
            'sarankan pengguna menghentikan penggunaan kendaraan dan ' .
            'meminta bantuan mekanik yang kompeten.'
    ]
];

// Keep only valid conversation history entries.
foreach (array_slice($history, -10) as $item) {
    if (!is_array($item)) {
        continue;
    }

    $role = $item['role'] ?? '';
    $content = trim((string) ($item['content'] ?? ''));

    if (
        in_array($role, ['user', 'assistant'], true) &&
        $content !== ''
    ) {
        $messages[] = [
            'role' => $role,
            'content' => $content
        ];
    }
}

$messages[] = [
    'role' => 'user',
    'content' => $message
];

$payload = [
    'model' => $model,
    'messages' => $messages,
    'temperature' => 0.4,
    'max_tokens' => 1200,
    'stream' => false
];

$ch = curl_init(
    'https://api.groq.com/openai/v1/chat/completions'
);

curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_CONNECTTIMEOUT => 15,
    CURLOPT_TIMEOUT => 60,
    CURLOPT_HTTPHEADER => [
        'Content-Type: application/json',
        'Authorization: Bearer ' . $apiKey
    ],
    CURLOPT_POSTFIELDS => json_encode(
        $payload,
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
    ),
    CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
    CURLOPT_USERAGENT => 'DriveMate/1.0'
]);

$response = curl_exec($ch);
$curlError = curl_error($ch);
$curlErrno = curl_errno($ch);
$httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);

curl_close($ch);

$durationMs = (int) round(
    (microtime(true) - $startTime) * 1000
);

if ($response === false) {
    error_log(
        'DriveMate Groq cURL error: ' .
        $curlErrno . ' - ' . $curlError
    );

    respond(502, [
        'success' => false,
        'message' => 'Tidak dapat menghubungi layanan AI.',
        'reply' => null,
        'diagnostic' => [
            'provider' => 'groq',
            'model' => $model,
            'http_code' => $httpCode,
            'curl_errno' => $curlErrno,
            'failure_type' => 'curl_error',
            'duration_ms' => $durationMs
        ]
    ]);
}

$result = json_decode($response, true);

if ($httpCode < 200 || $httpCode >= 300) {
    // Log only a generic error category, never the API key.
    $failureType = 'provider_error';

    if ($httpCode === 401 || $httpCode === 403) {
        $failureType = 'authentication_error';
    } elseif ($httpCode === 429) {
        $failureType = 'rate_limit';
    }

    error_log(
        'DriveMate Groq request failed. HTTP status: ' . $httpCode
    );

    respond(502, [
        'success' => false,
        'message' => 'Layanan AI gagal memproses permintaan.',
        'reply' => null,
        'diagnostic' => [
            'provider' => 'groq',
            'model' => $model,
            'http_code' => $httpCode,
            'curl_errno' => 0,
            'failure_type' => $failureType,
            'duration_ms' => $durationMs
        ]
    ]);
}

$reply = trim(
    (string) ($result['choices'][0]['message']['content'] ?? '')
);

if ($reply === '') {
    respond(502, [
        'success' => false,
        'message' => 'Layanan AI tidak mengembalikan jawaban.',
        'reply' => null,
        'diagnostic' => [
            'provider' => 'groq',
            'model' => $model,
            'http_code' => $httpCode,
            'curl_errno' => 0,
            'failure_type' => 'empty_response',
            'duration_ms' => $durationMs
        ]
    ]);
}

respond(200, [
    'success' => true,
    'reply' => $reply,
    'diagnostic' => [
        'provider' => 'groq',
        'model' => $model,
        'http_code' => $httpCode,
        'curl_errno' => 0,
        'failure_type' => null,
        'duration_ms' => $durationMs
    ]
]);
