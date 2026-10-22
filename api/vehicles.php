
<?php

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/db.php';

try {
    $method = $_SERVER['REQUEST_METHOD'];

    // GET: mengambil daftar kendaraan berdasarkan pengguna.
    if ($method === 'GET') {
        $userId = filter_input(
            INPUT_GET,
            'user_id',
            FILTER_VALIDATE_INT
        );

        if (!$userId || $userId < 1) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'message' => 'user_id wajib diisi dengan ID yang valid.',
            ]);
            exit;
        }

        $stmt = $pdo->prepare(
            'SELECT
                id,
                user_id,
                name,
                brand,
                model,
                plate_number,
                year,
                mileage,
                fuel_level,
                status,
                is_primary,
                last_service_date,
                tax_due_date,
                is_synced,
                created_at
             FROM public.vehicles
             WHERE user_id = :user_id
             ORDER BY id'
        );

        $stmt->execute([
            'user_id' => $userId,
        ]);

        echo json_encode([
            'success' => true,
            'data' => $stmt->fetchAll(),
        ]);
        exit;
    }

    // POST: menambahkan kendaraan baru.
    if ($method === 'POST') {
        $input = json_decode(
            file_get_contents('php://input'),
            true
        );

        if (!is_array($input)) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'message' => 'Format JSON tidak valid.',
            ]);
            exit;
        }

        $userId = filter_var(
            $input['user_id'] ?? null,
            FILTER_VALIDATE_INT
        );

        $name = trim((string) ($input['name'] ?? ''));
        $brand = trim((string) ($input['brand'] ?? ''));
        $model = trim((string) ($input['model'] ?? ''));
        $plate = trim((string) ($input['plate'] ?? ''));

        $year = filter_var(
            $input['year'] ?? null,
            FILTER_VALIDATE_INT
        );

        if (
            !$userId ||
            $userId < 1 ||
            $name === '' ||
            $brand === '' ||
            $plate === '' ||
            $year === false ||
            $year === null ||
            $year < 1886 ||
            $year > ((int) date('Y') + 1)
        ) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'message' => 'Data pengguna atau kendaraan tidak valid.',
            ]);
            exit;
        }

        // Pastikan pengguna tersedia di PostgreSQL.
        $checkUser = $pdo->prepare(
            'SELECT id
             FROM public.users
             WHERE id = :user_id'
        );

        $checkUser->execute([
            'user_id' => $userId,
        ]);

        if (!$checkUser->fetch()) {
            http_response_code(404);
            echo json_encode([
                'success' => false,
                'message' => 'Pengguna tidak ditemukan.',
            ]);
            exit;
        }

        $mileage = filter_var(
            $input['mileage'] ?? 0,
            FILTER_VALIDATE_INT
        );

        $fuelLevel = filter_var(
            $input['fuelLevel'] ?? 65,
            FILTER_VALIDATE_INT
        );

        if (
            $mileage === false ||
            $mileage < 0 ||
            $fuelLevel === false ||
            $fuelLevel < 0 ||
            $fuelLevel > 100
        ) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'message' => 'Jarak tempuh atau level bahan bakar tidak valid.',
            ]);
            exit;
        }

        // Normalisasi boolean agar PostgreSQL menerima true/false.
        $isPrimary = filter_var(
            $input['isPrimary'] ?? false,
            FILTER_VALIDATE_BOOLEAN
        );

        $status = trim(
            (string) ($input['status'] ?? 'Aktif')
        );

        $lastServiceDate = $input['lastServiceDate'] ?? null;
        $taxDueDate = $input['taxDueDate'] ?? null;

        $lastServiceDate = $lastServiceDate !== null
            ? trim((string) $lastServiceDate)
            : null;

        $taxDueDate = $taxDueDate !== null
            ? trim((string) $taxDueDate)
            : null;

        $stmt = $pdo->prepare(
            'INSERT INTO public.vehicles (
                user_id,
                name,
                brand,
                model,
                plate_number,
                year,
                mileage,
                fuel_level,
                status,
                is_primary,
                last_service_date,
                tax_due_date,
                is_synced
            )
            VALUES (
                :user_id,
                :name,
                :brand,
                :model,
                :plate,
                :year,
                :mileage,
                :fuel_level,
                :status,
                :is_primary,
                :last_service_date,
                :tax_due_date,
                1
            )
            RETURNING
                id,
                user_id,
                name,
                brand,
                model,
                plate_number,
                year,
                mileage,
                fuel_level,
                status,
                is_primary,
                last_service_date,
                tax_due_date,
                is_synced,
                created_at'
        );

        $stmt->execute([
            'user_id' => $userId,
            'name' => $name,
            'brand' => $brand,
            'model' => $model !== '' ? $model : null,
            'plate' => $plate,
            'year' => $year,
            'mileage' => $mileage,
            'fuel_level' => $fuelLevel,
            'status' => $status !== '' ? $status : 'Aktif',
            'is_primary' => $isPrimary ? 'true' : 'false',
            'last_service_date' => $lastServiceDate,
            'tax_due_date' => $taxDueDate,
        ]);

        http_response_code(201);

        echo json_encode([
            'success' => true,
            'message' => 'Kendaraan berhasil ditambahkan.',
            'data' => $stmt->fetch(),
        ]);
        exit;
    }

    header('Allow: GET, POST, OPTIONS');

    http_response_code(405);

    echo json_encode([
        'success' => false,
        'message' => 'Metode HTTP tidak didukung.',
    ]);

} catch (Throwable $e) {
    error_log(
        'Vehicles API error: ' . $e->__toString()
    );

    http_response_code(500);

    // Detail error untuk pengujian lokal.
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
}
