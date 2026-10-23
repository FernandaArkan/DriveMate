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
        'message' => 'Metode HTTP tidak didukung. Gunakan POST.',
    ]);
    exit;
}

require_once __DIR__ . '/db.php';

try {
    $rawInput = file_get_contents('php://input');
    $input = json_decode($rawInput, true);

    if (!is_array($input)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Format request JSON tidak valid.',
        ]);
        exit;
    }

    $identifier = trim((string) ($input['identifier'] ?? $input['email'] ?? $input['phone'] ?? ''));
    $password = (string) ($input['password'] ?? '');

    if ($identifier === '' || $password === '') {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Email/Nomor HP dan password wajib diisi.',
        ]);
        exit;
    }

    $stmt = $pdo->prepare(
        'SELECT id, name, email, phone, password_hash, created_at
         FROM public.users
         WHERE LOWER(email) = :ident_email OR phone = :ident_phone
         LIMIT 1'
    );

    $stmt->execute([
        'ident_email' => strtolower($identifier),
        'ident_phone' => $identifier,
    ]);

    $user = $stmt->fetch();

    if (!$user) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Email/Nomor HP atau password salah.',
        ]);
        exit;
    }

    $isValid = false;

    // Verifikasi password hash standar
    if (password_verify($password, $user['password_hash'])) {
        $isValid = true;
        if (password_needs_rehash($user['password_hash'], PASSWORD_BCRYPT)) {
            $newHash = password_hash($password, PASSWORD_BCRYPT);
            $upd = $pdo->prepare('UPDATE public.users SET password_hash = :hash WHERE id = :id');
            $upd->execute(['hash' => $newHash, 'id' => $user['id']]);
        }
    } elseif ($user['password_hash'] === 'TEMPORARY_DEMO_HASH' && $password === '123456') {
        // Migrasi transparan untuk akun demo default tanpa merusak data
        $isValid = true;
        $newHash = password_hash($password, PASSWORD_BCRYPT);
        $upd = $pdo->prepare('UPDATE public.users SET password_hash = :hash WHERE id = :id');
        $upd->execute(['hash' => $newHash, 'id' => $user['id']]);
    }

    if (!$isValid) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Email/Nomor HP atau password salah.',
        ]);
        exit;
    }

    $token = bin2hex(random_bytes(32));

    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Login berhasil.',
        'token' => $token,
        'data' => [
            'id' => (int) $user['id'],
            'name' => $user['name'],
            'email' => $user['email'],
            'phone' => $user['phone'],
            'created_at' => $user['created_at'],
        ],
    ]);
} catch (Throwable $e) {
    error_log('Login error: ' . $e->getMessage());

    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan sistem di server saat login.',
    ]);
}
