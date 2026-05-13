<?php

declare(strict_types=1);

require __DIR__ . '/bootstrap.php';

try {
    $rows = run_query(
        'SELECT id, tellercode, naam, soort_lid, aandachtspunt
         FROM pwa_teller_datakwaliteit
         ORDER BY soort_lid, naam
         LIMIT 1000'
    );

    json_response(['ok' => true, 'data' => $rows]);
} catch (Throwable $error) {
    handle_error($error);
}
