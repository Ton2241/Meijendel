<?php

declare(strict_types=1);

require dirname(__DIR__) . '/bootstrap.php';

json_response([
    'ok' => true,
    'data' => [
        'authenticated' => !auth_enabled() || !empty($_SESSION['teller_id']),
        'email' => $_SESSION['email'] ?? null,
    ],
]);
