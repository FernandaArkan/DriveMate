<?php

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

if (str_starts_with($uri, '/api/')) {
    $script = substr($uri, 4);
} else {
    $script = $uri;
}

$possiblePaths = [
    __DIR__ . $script,
    __DIR__ . '/api' . $script,
    __DIR__ . $uri,
];

foreach ($possiblePaths as $path) {
    if (is_file($path)) {
        require $path;
        exit;
    }
}

return false;
