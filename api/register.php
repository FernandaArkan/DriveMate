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

    $name = trim((string) ($input['name'] ?? ''));
    $email = strtolower(trim((string) ($input['email'] ?? '')));
    $phone = trim((string) ($input['phone'] ?? ''));
    $password = (string) ($input['password'] ?? '');

    // Validasi Name
    if ($name === '' || mb_strlen($name) < 3 || mb_strlen($name) > 100) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Nama lengkap minimal 3 karakter dan maksimal 100 karakter.',
        ]);
        exit;
    }

    // Validasi Email
    if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Format email tidak valid (contoh: nama@domain.com).',
        ]);
        exit;
    }

    // Validasi Phone (10-15 digit)
    $digitsPhone = preg_replace('/\D/', '', $phone);
    if (strlen($digitsPhone) < 10 || strlen($digitsPhone) > 15) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Nomor HP harus berupa 10-15 digit angka.',
        ]);
        exit;
    }

    // Validasi Password
    if (strlen($password) < 6) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Password minimal 6 karakter.',
        ]);
        exit;
    }

    // Cek duplikasi email
    $checkEmail = $pdo->prepare('SELECT id FROM public.users WHERE LOWER(email) = :email LIMIT 1');
    $checkEmail->execute(['email' => $email]);
    if ($checkEmail->fetch()) {
        http_response_code(409);
        echo json_encode([
            'success' => false,
            'message' => 'Email sudah terdaftar. Silakan login atau gunakan email lain.',
        ]);
        exit;
    }

    // Cek duplikasi nomor HP jika ada
    $checkPhone = $pdo->prepare('SELECT id FROM public.users WHERE phone = :phone LIMIT 1');
    $checkPhone->execute(['phone' => $phone]);
    if ($checkPhone->fetch()) {
        http_response_code(409);
        echo json_encode([
            'success' => false,
            'message' => 'Nomor HP sudah terdaftar pada akun lain.',
        ]);
        exit;
    }

    // Hash password secara aman
    $passwordHash = password_hash($password, PASSWORD_BCRYPT);
    $token = bin2hex(random_bytes(32));

    // Simpan ke database
    $stmt = $pdo->prepare(
        'INSERT INTO public.users (name, email, phone, password_hash)
         VALUES (:name, :email, :phone, :password_hash)
         RETURNING id, name, email, phone, created_at'
    );

    $stmt->execute([
        'name' => $name,
        'email' => $email,
        'phone' => $phone,
        'password_hash' => $passwordHash,
    ]);

    $user = $stmt->fetch();

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'message' => 'Pendaftaran berhasil dikonfirmasi oleh server! Selamat datang di DriveMate.',
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
    error_log('Register error: ' . $e->getMessage());

    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan sistem di server saat registrasi.',
    ]);
}
