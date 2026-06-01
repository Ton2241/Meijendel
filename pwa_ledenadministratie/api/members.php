<?php

declare(strict_types=1);

require __DIR__ . '/bootstrap.php';

try {
    $search = input_string('search');
    $type = input_string('type', 40);
    $quality = input_string('quality', 40);
    $city = input_string('city', 80);
    $activeYear = input_int('activeYear');

    $where = [];
    $params = [];

    if ($search !== '') {
        $where[] = '(l.naam LIKE :searchName OR l.tellercode LIKE :searchCode OR l.email LIKE :searchEmail OR l.woonplaats LIKE :searchCity)';
        $params['searchName'] = '%' . $search . '%';
        $params['searchCode'] = '%' . $search . '%';
        $params['searchEmail'] = '%' . $search . '%';
        $params['searchCity'] = '%' . $search . '%';
    }
    if ($type !== '') {
        $where[] = 'l.soort_lid = :type';
        $params['type'] = $type;
    }
    if ($quality !== '') {
        $where[] = 'l.datakwaliteit = :quality';
        $params['quality'] = $quality;
    }
    if ($city !== '') {
        $where[] = 'l.woonplaats LIKE :city';
        $params['city'] = '%' . $city . '%';
    }
    if ($activeYear !== null) {
        $where[] = 'EXISTS (
            SELECT 1
            FROM plot_jaar_teller pjy
            WHERE pjy.teller_id = l.id AND pjy.jaar = :activeYear
        )';
        $params['activeYear'] = $activeYear;
    }

    $sql = "SELECT
              l.id,
              l.tellercode,
              l.naam,
              l.soort_lid,
              l.woonplaats,
              l.email,
              l.telefoon_mobiel,
              l.beheer_status,
              l.beheer_opmerking,
              l.aantal_jaren_geteld,
              l.aantal_plots,
              l.aantal_plotjaren,
              l.eerste_jaar,
              l.laatste_jaar,
              l.datakwaliteit
            FROM pwa_teller_lijst l";
    if ($where) {
        $sql .= ' WHERE ' . implode(' AND ', $where);
    }
    $sql .= ' ORDER BY l.achternaam, l.voornaam, l.tellercode LIMIT 500';

    json_response(['ok' => true, 'data' => run_query($sql, $params)]);
} catch (Throwable $error) {
    handle_error($error);
}
