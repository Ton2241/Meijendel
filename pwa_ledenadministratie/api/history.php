<?php

declare(strict_types=1);

require __DIR__ . '/bootstrap.php';

try {
    $year = input_int('year');
    $search = input_string('search');
    $where = [];
    $params = [];

    if ($year !== null) {
        $where[] = 'pjt.jaar = :year';
        $params['year'] = $year;
    }
    if ($search !== '') {
        $where[] = "(TRIM(CONCAT_WS(' ', NULLIF(t.voornaam, ''), NULLIF(t.tussenvoegsel, ''), NULLIF(t.achternaam, ''))) LIKE :searchName
            OR t.tellercode LIKE :searchCode
            OR COALESCE(p.kavel_nummer, p.plot_naam, CAST(p.plot_id AS CHAR)) LIKE :searchPlots)";
        $params['searchName'] = '%' . $search . '%';
        $params['searchCode'] = '%' . $search . '%';
        $params['searchPlots'] = '%' . $search . '%';
    }

    $sql = "SELECT
              pjt.id,
              pjt.teller_id,
              t.tellercode,
              TRIM(CONCAT_WS(' ', NULLIF(t.voornaam, ''), NULLIF(t.tussenvoegsel, ''), NULLIF(t.achternaam, ''))) AS naam,
              pjt.jaar,
              pjt.plot_id,
              p.kavel_nummer,
              p.plot_naam,
              COALESCE(p.kavel_nummer, p.plot_naam, CAST(p.plot_id AS CHAR)) AS kavels,
              1 AS aantal_plots
            FROM plot_jaar_teller pjt
            JOIN tellers t ON t.id = pjt.teller_id
            LEFT JOIN plots p ON p.plot_id = pjt.plot_id";
    if ($where) {
        $sql .= ' WHERE ' . implode(' AND ', $where);
    }
    $sql .= ' ORDER BY naam, pjt.jaar DESC, p.kavel_nummer, p.plot_naam LIMIT 2000';

    json_response(['ok' => true, 'data' => run_query($sql, $params)]);
} catch (Throwable $error) {
    handle_error($error);
}
