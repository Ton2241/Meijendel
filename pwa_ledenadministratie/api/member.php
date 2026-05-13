<?php

declare(strict_types=1);

require __DIR__ . '/bootstrap.php';

try {
    $id = (int) ($_GET['id'] ?? 0);
    if ($id <= 0) {
        json_response(['ok' => true, 'data' => null]);
    }

    $rows = run_query('SELECT * FROM pwa_teller_detail WHERE id = :id', ['id' => $id]);

    json_response(['ok' => true, 'data' => $rows[0] ?? null]);
} catch (Throwable $error) {
    handle_error($error);
}
