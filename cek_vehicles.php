<?php
require __DIR__ . '/api/db.php';

$sql = "SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'vehicles'
        ORDER BY ordinal_position";

foreach ($pdo->query($sql) as $row) {
    echo $row['column_name']
        . ' | ' . $row['data_type']
        . ' | nullable=' . $row['is_nullable']
        . ' | default=' . ($row['column_default'] ?? '-')
        . PHP_EOL;
}
