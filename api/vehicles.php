<?php

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/db.php';

try {
    $method = $_SERVER['REQUEST_METHOD'];

    // GET: mengambil daftar kendaraan berdasarkan user_id
    if ($method === 'GET') {
        $userId = filter_input(INPUT_GET, 'user_id', FILTER_VALIDATE_INT);

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
             ORDER BY is_primary DESC, id ASC'
        );

        $stmt->execute(['user_id' => $userId]);
        $rows = $stmt->fetchAll();

        // Format tipe data konsisten untuk client Flutter
        $vehicles = array_map(function ($row) {
            return [
                'id' => (int) $row['id'],
                'user_id' => (int) $row['user_id'],
                'name' => $row['name'],
                'brand' => $row['brand'] ?? '',
                'model' => $row['model'] ?? '',
                'plate' => $row['plate_number'] ?? '',
                'plate_number' => $row['plate_number'] ?? '',
                'year' => (int) $row['year'],
                'mileage' => (int) $row['mileage'],
                'fuelLevel' => (int) $row['fuel_level'],
                'fuel_level' => (int) $row['fuel_level'],
                'status' => $row['status'] ?? 'Aktif',
                'isPrimary' => (bool) $row['is_primary'],
                'is_primary' => (bool) $row['is_primary'],
                'lastServiceDate' => $row['last_service_date'],
                'last_service_date' => $row['last_service_date'],
                'taxDueDate' => $row['tax_due_date'],
                'tax_due_date' => $row['tax_due_date'],
                'isSynced' => (int) $row['is_synced'],
                'is_synced' => (int) $row['is_synced'],
                'createdAt' => $row['created_at'],
                'created_at' => $row['created_at'],
            ];
        }, $rows);

        echo json_encode([
            'success' => true,
            'data' => $vehicles,
        ]);
        exit;
    }

    // POST: menambahkan kendaraan baru atau batch sync
    if ($method === 'POST') {
        $rawInput = file_get_contents('php://input');
        $input = json_decode($rawInput, true);

        if (!is_array($input)) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'message' => 'Format JSON tidak valid.',
            ]);
            exit;
        }

        // Cek apakah batch sync
        if (isset($input['action']) && $input['action'] === 'sync' && isset($input['vehicles']) && is_array($input['vehicles'])) {
            $userId = filter_var($input['user_id'] ?? null, FILTER_VALIDATE_INT);
            if (!$userId || $userId < 1) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'user_id tidak valid untuk sinkronisasi.']);
                exit;
            }

            $syncedCount = 0;
            $pdo->beginTransaction();
            try {
                foreach ($input['vehicles'] as $v) {
                    $vId = isset($v['id']) && (int) $v['id'] > 0 ? (int) $v['id'] : null;
                    $name = trim((string) ($v['name'] ?? ''));
                    $brand = trim((string) ($v['brand'] ?? ''));
                    $plate = trim((string) ($v['plate'] ?? $v['plate_number'] ?? ''));
                    $year = (int) ($v['year'] ?? date('Y'));
                    $mileage = (int) ($v['mileage'] ?? 0);
                    $fuelLevel = (int) ($v['fuelLevel'] ?? $v['fuel_level'] ?? 65);
                    $status = trim((string) ($v['status'] ?? 'Aktif'));
                    $isPrimary = !empty($v['isPrimary']) || !empty($v['is_primary']);
                    $lastService = $v['lastServiceDate'] ?? $v['last_service_date'] ?? null;
                    $taxDue = $v['taxDueDate'] ?? $v['tax_due_date'] ?? null;

                    if ($name === '') continue;

                    if ($isPrimary) {
                        $updPrimary = $pdo->prepare('UPDATE public.vehicles SET is_primary = false WHERE user_id = :uid');
                        $updPrimary->execute(['uid' => $userId]);
                    }

                    // Jika ID lokal ada dan ada di server, lakukan UPDATE. Jika tidak, INSERT baru
                    $exists = false;
                    if ($vId !== null) {
                        $check = $pdo->prepare('SELECT id FROM public.vehicles WHERE id = :id AND user_id = :uid');
                        $check->execute(['id' => $vId, 'uid' => $userId]);
                        $exists = (bool) $check->fetch();
                    }

                    if ($exists) {
                        $stmt = $pdo->prepare(
                            'UPDATE public.vehicles
                             SET name = :name, brand = :brand, plate_number = :plate, year = :year,
                                 mileage = :mileage, fuel_level = :fuel, status = :status,
                                 is_primary = :is_pri, last_service_date = :last_svc, tax_due_date = :tax,
                                 is_synced = 1
                             WHERE id = :id AND user_id = :uid'
                        );
                        $stmt->execute([
                            'name' => $name,
                            'brand' => $brand,
                            'plate' => $plate,
                            'year' => $year,
                            'mileage' => $mileage,
                            'fuel' => $fuelLevel,
                            'status' => $status,
                            'is_pri' => $isPrimary ? 't' : 'f',
                            'last_svc' => $lastService,
                            'tax' => $taxDue,
                            'id' => $vId,
                            'uid' => $userId,
                        ]);
                    } else {
                        $stmt = $pdo->prepare(
                            'INSERT INTO public.vehicles (
                                user_id, name, brand, model, plate_number, year, mileage, fuel_level,
                                status, is_primary, last_service_date, tax_due_date, is_synced
                             ) VALUES (
                                :uid, :name, :brand, :brand, :plate, :year, :mileage, :fuel,
                                :status, :is_pri, :last_svc, :tax, 1
                             )'
                        );
                        $stmt->execute([
                            'uid' => $userId,
                            'name' => $name,
                            'brand' => $brand,
                            'plate' => $plate,
                            'year' => $year,
                            'mileage' => $mileage,
                            'fuel' => $fuelLevel,
                            'status' => $status,
                            'is_pri' => $isPrimary ? 't' : 'f',
                            'last_svc' => $lastService,
                            'tax' => $taxDue,
                        ]);
                    }
                    $syncedCount++;
                }
                $pdo->commit();

                echo json_encode([
                    'success' => true,
                    'message' => "Sinkronisasi berhasil ($syncedCount kendaraan diperbarui).",
                    'synced_count' => $syncedCount,
                ]);
                exit;
            } catch (Throwable $e) {
                $pdo->rollBack();
                throw $e;
            }
        }

        // Single Vehicle POST
        $userId = filter_var($input['user_id'] ?? null, FILTER_VALIDATE_INT);
        $name = trim((string) ($input['name'] ?? ''));
        $brand = trim((string) ($input['brand'] ?? ''));
        $model = trim((string) ($input['model'] ?? $name));
        $plate = trim((string) ($input['plate'] ?? $input['plate_number'] ?? ''));
        $year = filter_var($input['year'] ?? null, FILTER_VALIDATE_INT);

        if (!$userId || $userId < 1 || $name === '' || $brand === '' || $plate === '' || $year === false || $year === null) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'message' => 'Data kendaraan tidak valid. Nama, merk, plat, dan tahun wajib diisi.',
            ]);
            exit;
        }

        // Pastikan user ada
        $checkUser = $pdo->prepare('SELECT id FROM public.users WHERE id = :user_id');
        $checkUser->execute(['user_id' => $userId]);
        if (!$checkUser->fetch()) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Pengguna tidak ditemukan.']);
            exit;
        }

        $mileage = filter_var($input['mileage'] ?? 0, FILTER_VALIDATE_INT);
        $fuelLevel = filter_var($input['fuelLevel'] ?? $input['fuel_level'] ?? 65, FILTER_VALIDATE_INT);
        $isPrimary = filter_var($input['isPrimary'] ?? $input['is_primary'] ?? false, FILTER_VALIDATE_BOOLEAN);
        $status = trim((string) ($input['status'] ?? 'Aktif'));
        $lastServiceDate = $input['lastServiceDate'] ?? $input['last_service_date'] ?? null;
        $taxDueDate = $input['taxDueDate'] ?? $input['tax_due_date'] ?? null;

        if ($isPrimary) {
            $clearPrimary = $pdo->prepare('UPDATE public.vehicles SET is_primary = false WHERE user_id = :uid');
            $clearPrimary->execute(['uid' => $userId]);
        }

        $stmt = $pdo->prepare(
            'INSERT INTO public.vehicles (
                user_id, name, brand, model, plate_number, year, mileage, fuel_level,
                status, is_primary, last_service_date, tax_due_date, is_synced
            ) VALUES (
                :user_id, :name, :brand, :model, :plate, :year, :mileage, :fuel_level,
                :status, :is_primary, :last_service_date, :tax_due_date, 1
            )
            RETURNING
                id, user_id, name, brand, model, plate_number, year, mileage, fuel_level,
                status, is_primary, last_service_date, tax_due_date, is_synced, created_at'
        );

        $stmt->execute([
            'user_id' => $userId,
            'name' => $name,
            'brand' => $brand,
            'model' => $model !== '' ? $model : null,
            'plate' => $plate,
            'year' => $year,
            'mileage' => $mileage !== false ? $mileage : 0,
            'fuel_level' => $fuelLevel !== false ? $fuelLevel : 65,
            'status' => $status !== '' ? $status : 'Aktif',
            'is_primary' => $isPrimary ? 't' : 'f',
            'last_service_date' => $lastServiceDate,
            'tax_due_date' => $taxDueDate,
        ]);

        $created = $stmt->fetch();

        http_response_code(201);
        echo json_encode([
            'success' => true,
            'message' => 'Kendaraan berhasil ditambahkan.',
            'data' => [
                'id' => (int) $created['id'],
                'user_id' => (int) $created['user_id'],
                'name' => $created['name'],
                'brand' => $created['brand'] ?? '',
                'plate' => $created['plate_number'] ?? '',
                'year' => (int) $created['year'],
                'mileage' => (int) $created['mileage'],
                'fuelLevel' => (int) $created['fuel_level'],
                'status' => $created['status'] ?? 'Aktif',
                'isPrimary' => (bool) $created['is_primary'],
                'lastServiceDate' => $created['last_service_date'],
                'taxDueDate' => $created['tax_due_date'],
                'isSynced' => (int) $created['is_synced'],
                'createdAt' => $created['created_at'],
            ],
        ]);
        exit;
    }

    // PUT: memperbarui data kendaraan
    if ($method === 'PUT') {
        $rawInput = file_get_contents('php://input');
        $input = json_decode($rawInput, true);

        if (!is_array($input)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Format JSON tidak valid.']);
            exit;
        }

        $id = filter_var($input['id'] ?? null, FILTER_VALIDATE_INT);
        $userId = filter_var($input['user_id'] ?? 1, FILTER_VALIDATE_INT);

        if (!$id || $id < 1) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'ID kendaraan wajib diisi.']);
            exit;
        }

        $name = trim((string) ($input['name'] ?? ''));
        $brand = trim((string) ($input['brand'] ?? ''));
        $plate = trim((string) ($input['plate'] ?? $input['plate_number'] ?? ''));
        $year = (int) ($input['year'] ?? date('Y'));
        $mileage = (int) ($input['mileage'] ?? 0);
        $fuelLevel = (int) ($input['fuelLevel'] ?? $input['fuel_level'] ?? 65);
        $status = trim((string) ($input['status'] ?? 'Aktif'));
        $isPrimary = filter_var($input['isPrimary'] ?? $input['is_primary'] ?? false, FILTER_VALIDATE_BOOLEAN);
        $lastServiceDate = $input['lastServiceDate'] ?? $input['last_service_date'] ?? null;
        $taxDueDate = $input['taxDueDate'] ?? $input['tax_due_date'] ?? null;

        if ($isPrimary) {
            $clear = $pdo->prepare('UPDATE public.vehicles SET is_primary = false WHERE user_id = :uid AND id != :id');
            $clear->execute(['uid' => $userId, 'id' => $id]);
        }

        $stmt = $pdo->prepare(
            'UPDATE public.vehicles
             SET name = :name, brand = :brand, plate_number = :plate, year = :year,
                 mileage = :mileage, fuel_level = :fuel, status = :status,
                 is_primary = :is_pri, last_service_date = :last_svc, tax_due_date = :tax,
                 is_synced = 1
             WHERE id = :id AND user_id = :uid
             RETURNING id, user_id, name, brand, plate_number, year, mileage, fuel_level,
                       status, is_primary, last_service_date, tax_due_date, is_synced, created_at'
        );

        $stmt->execute([
            'name' => $name,
            'brand' => $brand,
            'plate' => $plate,
            'year' => $year,
            'mileage' => $mileage,
            'fuel' => $fuelLevel,
            'status' => $status,
            'is_pri' => $isPrimary ? 't' : 'f',
            'last_svc' => $lastServiceDate,
            'tax' => $taxDueDate,
            'id' => $id,
            'uid' => $userId,
        ]);

        $updated = $stmt->fetch();
        if (!$updated) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Kendaraan tidak ditemukan.']);
            exit;
        }

        echo json_encode([
            'success' => true,
            'message' => 'Data kendaraan berhasil diperbarui.',
            'data' => [
                'id' => (int) $updated['id'],
                'user_id' => (int) $updated['user_id'],
                'name' => $updated['name'],
                'brand' => $updated['brand'] ?? '',
                'plate' => $updated['plate_number'] ?? '',
                'year' => (int) $updated['year'],
                'mileage' => (int) $updated['mileage'],
                'fuelLevel' => (int) $updated['fuel_level'],
                'status' => $updated['status'] ?? 'Aktif',
                'isPrimary' => (bool) $updated['is_primary'],
                'lastServiceDate' => $updated['last_service_date'],
                'taxDueDate' => $updated['tax_due_date'],
                'isSynced' => (int) $updated['is_synced'],
                'createdAt' => $updated['created_at'],
            ],
        ]);
        exit;
    }

    // DELETE: menghapus kendaraan
    if ($method === 'DELETE') {
        $id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);
        $userId = filter_input(INPUT_GET, 'user_id', FILTER_VALIDATE_INT) ?: 1;

        if (!$id || $id < 1) {
            $raw = file_get_contents('php://input');
            $data = json_decode($raw, true);
            if (is_array($data) && isset($data['id'])) {
                $id = (int) $data['id'];
                if (isset($data['user_id'])) $userId = (int) $data['user_id'];
            }
        }

        if (!$id || $id < 1) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'ID kendaraan wajib disertakan.']);
            exit;
        }

        $stmt = $pdo->prepare('DELETE FROM public.vehicles WHERE id = :id AND user_id = :uid');
        $stmt->execute(['id' => $id, 'uid' => $userId]);

        echo json_encode([
            'success' => true,
            'message' => 'Kendaraan berhasil dihapus.',
        ]);
        exit;
    }

    header('Allow: GET, POST, PUT, DELETE, OPTIONS');
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Metode HTTP tidak didukung.',
    ]);
} catch (Throwable $e) {
    error_log('Vehicles API error: ' . $e->getMessage());

    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan sistem saat memproses kendaraan: ' . $e->getMessage(),
    ]);
}
