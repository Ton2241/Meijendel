<?php

declare(strict_types=1);

require __DIR__ . '/bootstrap.php';

try {
    $rows = run_query(
        "SELECT
           plot_id,
           kavel_nummer,
           plot_naam,
           in_gebruik,
           COALESCE(kavel_nummer, plot_naam, CAST(plot_id AS CHAR)) AS label
         FROM plots
         ORDER BY in_gebruik DESC, kavel_nummer, plot_naam, plot_id"
    );

    json_response(['ok' => true, 'data' => $rows]);
} catch (Throwable $error) {
    handle_error($error);
}
