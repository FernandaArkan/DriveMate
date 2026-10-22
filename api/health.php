<?php

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . '/db.php';

try {
    $result = $pdo->query(
        'SELECT current_database() AS database_name'
    )->fetch();

    echo json_encode([
        'success' => true,
        'message' => 'Backend PHP terhubung ke PostgreSQL.',
        'database' => $result['database_name'],
    ]);
} catch (PDOException $e) {
    error_log('Health check failed: ' . $e->getMessage());

    http_response_code(500);

    echo json_encode([
        'success' => false,
        'message' => 'Pemeriksaan database gagal.',
    ]);
}
