<?php

declare(strict_types=1);

require __DIR__ . '/bootstrap.php';

try {
    $year = input_int('year');
    $search = input_string('search');
    $where = [];
    $params = [];

    if ($year !== null) {
        $where[] = 'jaar = :year';
        $params['year'] = $year;
    }
    if ($search !== '') {
        $where[] = '(naam LIKE :searchName OR tellercode LIKE :searchCode OR kavels LIKE :searchPlots)';
        $params['searchName'] = '%' . $search . '%';
        $params['searchCode'] = '%' . $search . '%';
        $params['searchPlots'] = '%' . $search . '%';
    }

    $sql = 'SELECT teller_id, tellercode, naam, jaar, aantal_plots, kavels FROM pwa_teller_telhistorie';
    if ($where) {
        $sql .= ' WHERE ' . implode(' AND ', $where);
    }
    $sql .= ' ORDER BY naam, jaar DESC LIMIT 2000';

    json_response(['ok' => true, 'data' => run_query($sql, $params)]);
} catch (Throwable $error) {
    handle_error($error);
}
