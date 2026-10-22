<?php
require __DIR__ . '/api/db.php';

$sql = "SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name IN ('users', 'vehicles', 'trips', 'service_record', 'reminders')
        ORDER BY table_name, ordinal_position";

foreach ($pdo->query($sql) as $row) {
    echo $row['table_name'] . ' : ' . $row['column_name'] . PHP_EOL;
}
