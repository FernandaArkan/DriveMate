<?php
require __DIR__ . '/api/db.php';

$sql = "SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'service_record'
        ORDER BY ordinal_position";

$rows = $pdo->query($sql);

foreach ($rows as $row) {
    echo $row['column_name'] . ' : ' . $row['data_type'] . PHP_EOL;
}
