<?php

declare(strict_types=1);

require __DIR__ . '/bootstrap.php';

try {
    $rows = run_query(
        'SELECT jaar, actieve_tellers, getelde_plots, plotjaren
         FROM pwa_actieve_tellers_per_jaar
         ORDER BY jaar DESC'
    );

    json_response(['ok' => true, 'data' => $rows]);
} catch (Throwable $error) {
    handle_error($error);
}
