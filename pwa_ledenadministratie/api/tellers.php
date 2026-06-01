<?php

declare(strict_types=1);

require __DIR__ . '/bootstrap.php';

try {
    $rows = run_query(
        "SELECT
           id,
           tellercode,
           achternaam,
           voornaam,
           tussenvoegsel,
           TRIM(CONCAT_WS(' ', NULLIF(voornaam, ''), NULLIF(tussenvoegsel, ''), NULLIF(achternaam, ''))) AS naam
         FROM tellers
         ORDER BY achternaam, voornaam, tellercode"
    );

    json_response(['ok' => true, 'data' => $rows]);
} catch (Throwable $error) {
    handle_error($error);
}
