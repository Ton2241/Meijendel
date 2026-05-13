<?php

declare(strict_types=1);

require __DIR__ . '/bootstrap.php';

try {
    $rows = run_query(
        "SELECT label, waarde
         FROM pwa_teller_stats
         ORDER BY FIELD(
           label,
           'totaal tellers',
           'actieve gewone leden',
           'aspiranten',
           'oudtellers',
           'zonder email',
           'zonder mobiel',
           'zonder woonplaats'
         )"
    );

    json_response(['ok' => true, 'data' => $rows]);
} catch (Throwable $error) {
    handle_error($error);
}
