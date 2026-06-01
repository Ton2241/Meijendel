<?php

declare(strict_types=1);

require dirname(__DIR__) . '/bootstrap.php';

const MEMBER_FIELDS = [
    'voornaam' => 80,
    'tussenvoegsel' => 40,
    'achternaam' => 120,
    'straat' => 120,
    'huisnummer' => 30,
    'postcode' => 20,
    'woonplaats' => 120,
    'email' => 255,
    'telefoon_vast' => 40,
    'telefoon_mobiel' => 40,
    'soort_lid' => 40,
    'bandnummer' => 80,
];

try {
    require_admin();
    require_csrf();

    $id = (int) ($_POST['id'] ?? 0);
    if ($id <= 0) {
        json_response(['ok' => false, 'error' => 'Ongeldig lid.'], 422);
    }

    $values = [];
    foreach (MEMBER_FIELDS as $field => $maxLength) {
        $values[$field] = post_input_string($field, $maxLength);
    }

    if ($values['achternaam'] === '') {
        json_response(['ok' => false, 'error' => 'Achternaam is verplicht.'], 422);
    }
    if ($values['email'] !== '' && !filter_var($values['email'], FILTER_VALIDATE_EMAIL)) {
        json_response(['ok' => false, 'error' => 'E-mailadres is ongeldig.'], 422);
    }

    $allowedTypes = ['aspirant', 'gewoon', 'buitengewoon', 'ondersteunend', 'erelid', 'onbekend', 'oudteller'];
    if ($values['soort_lid'] !== '' && !in_array($values['soort_lid'], $allowedTypes, true)) {
        json_response(['ok' => false, 'error' => 'Lidtype is niet toegestaan.'], 422);
    }

    $beheerStatus = post_input_string('beheer_status', 40);
    $allowedStatuses = ['actief', 'inactief', 'nader_controleren'];
    if (!in_array($beheerStatus, $allowedStatuses, true)) {
        json_response(['ok' => false, 'error' => 'Beheerstatus is niet toegestaan.'], 422);
    }
    $opmerking = post_input_string('beheer_opmerking', 4000);

    $pdo = db();
    $pdo->beginTransaction();

    $statement = $pdo->prepare(
        'SELECT t.id, t.tellercode, t.voornaam, t.tussenvoegsel, t.achternaam, t.straat, t.huisnummer,
                t.postcode, t.woonplaats, t.email, t.telefoon_vast, t.telefoon_mobiel,
                t.soort_lid, t.bandnummer,
                COALESCE(m.beheer_status, :default_status) AS beheer_status,
                COALESCE(m.opmerking, :default_note) AS beheer_opmerking
         FROM tellers t
         LEFT JOIN pwa_teller_admin_meta m ON m.teller_id = t.id
         WHERE t.id = :id
         FOR UPDATE'
    );
    $statement->execute([
        'default_status' => 'actief',
        'default_note' => '',
        'id' => $id,
    ]);
    $old = $statement->fetch();
    if (!$old) {
        $pdo->rollBack();
        json_response(['ok' => false, 'error' => 'Lid niet gevonden.'], 404);
    }

    $updates = [];
    $params = ['id' => $id];
    foreach ($values as $field => $value) {
        $updates[] = $field . ' = :' . $field;
        $params[$field] = $value === '' ? null : $value;
    }
    $pdo->prepare('UPDATE tellers SET ' . implode(', ', $updates) . ' WHERE id = :id')->execute($params);

    $meta = $pdo->prepare(
        'INSERT INTO pwa_teller_admin_meta
           (teller_id, beheer_status, opmerking, updated_by_teller_id, updated_by_email)
         VALUES
           (:teller_id, :beheer_status, :opmerking, :actor_teller_id, :actor_email)
         ON DUPLICATE KEY UPDATE
           beheer_status = VALUES(beheer_status),
           opmerking = VALUES(opmerking),
           updated_by_teller_id = VALUES(updated_by_teller_id),
           updated_by_email = VALUES(updated_by_email)'
    );
    $meta->execute([
        'teller_id' => $id,
        'beheer_status' => $beheerStatus,
        'opmerking' => $opmerking === '' ? null : $opmerking,
        'actor_teller_id' => $_SESSION['teller_id'] ?? null,
        'actor_email' => $_SESSION['email'] ?? null,
    ]);

    $new = $values + [
        'beheer_status' => $beheerStatus,
        'beheer_opmerking' => $opmerking,
    ];
    $oldLogged = array_intersect_key($old, $new);
    $changed = array_filter($new, static function ($value, $field) use ($oldLogged): bool {
        return (string) ($oldLogged[$field] ?? '') !== (string) $value;
    }, ARRAY_FILTER_USE_BOTH);
    if ($changed) {
        $audit = $pdo->prepare(
            'INSERT INTO pwa_member_change_log
               (teller_id, actor_teller_id, actor_email, action, old_values, new_values, ip, user_agent_hash)
             VALUES
               (:teller_id, :actor_teller_id, :actor_email, :action, :old_values, :new_values, :ip, :user_agent_hash)'
        );
        $audit->execute([
            'teller_id' => $id,
            'actor_teller_id' => $_SESSION['teller_id'] ?? null,
            'actor_email' => $_SESSION['email'] ?? null,
            'action' => 'member_update',
            'old_values' => json_encode($oldLogged, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'new_values' => json_encode($new, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'ip' => ip_binary(),
            'user_agent_hash' => user_agent_hash(),
        ]);
    }

    $pdo->commit();

    $rows = run_query('SELECT * FROM pwa_teller_detail WHERE id = :id', ['id' => $id]);
    json_response(['ok' => true, 'data' => $rows[0] ?? null]);
} catch (Throwable $error) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    handle_error($error);
}
