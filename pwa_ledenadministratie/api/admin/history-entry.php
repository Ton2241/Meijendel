<?php

declare(strict_types=1);

require dirname(__DIR__) . '/bootstrap.php';

function post_int_value(string $key): int
{
    $value = trim((string) ($_POST[$key] ?? ''));
    if (!preg_match('/^\d+$/', $value)) {
        json_response(['ok' => false, 'error' => 'Ongeldige waarde voor ' . $key . '.'], 422);
    }

    return (int) $value;
}

function fetch_history_entry(PDO $pdo, int $id): ?array
{
    $statement = $pdo->prepare(
        'SELECT id, teller_id, plot_id, jaar
         FROM plot_jaar_teller
         WHERE id = :id'
    );
    $statement->execute(['id' => $id]);
    $row = $statement->fetch();

    return $row ?: null;
}

function assert_exists(PDO $pdo, string $table, string $column, int $id, string $message): void
{
    $statement = $pdo->prepare("SELECT 1 FROM {$table} WHERE {$column} = :id LIMIT 1");
    $statement->execute(['id' => $id]);
    if (!$statement->fetchColumn()) {
        json_response(['ok' => false, 'error' => $message], 422);
    }
}

function resolve_teller_id(PDO $pdo): int
{
    $explicitId = trim((string) ($_POST['teller_id'] ?? ''));
    if ($explicitId !== '') {
        return post_int_value('teller_id');
    }

    $code = post_input_string('teller_code', 40);
    $search = post_input_string('teller_search', 120);
    if ($code !== '') {
        $statement = $pdo->prepare(
            "SELECT id
             FROM tellers
             WHERE tellercode = :code
                OR achternaam LIKE :search
                OR TRIM(CONCAT_WS(' ', NULLIF(voornaam, ''), NULLIF(tussenvoegsel, ''), NULLIF(achternaam, ''))) LIKE :search
             ORDER BY (tellercode = :code) DESC
             LIMIT 2"
        );
        $statement->execute(['code' => $code, 'search' => '%' . $code . '%']);
    } elseif ($search !== '') {
        $statement = $pdo->prepare(
            "SELECT id
             FROM tellers
             WHERE achternaam LIKE :search
                OR tellercode LIKE :search
                OR TRIM(CONCAT_WS(' ', NULLIF(voornaam, ''), NULLIF(tussenvoegsel, ''), NULLIF(achternaam, ''))) LIKE :search
             LIMIT 2"
        );
        $statement->execute(['search' => '%' . $search . '%']);
    } else {
        json_response(['ok' => false, 'error' => 'Vul een tellercode of achternaam/naam in.'], 422);
    }
    $rows = $statement->fetchAll();
    if (count($rows) !== 1) {
        json_response(['ok' => false, 'error' => count($rows) > 1 ? 'Tellerzoekterm is niet uniek. Gebruik de tellercode.' : 'Teller niet gevonden.'], 422);
    }

    return (int) $rows[0]['id'];
}

function resolve_plot_id(PDO $pdo): int
{
    $explicitId = trim((string) ($_POST['plot_id'] ?? ''));
    if ($explicitId !== '') {
        return post_int_value('plot_id');
    }

    $search = post_input_string('plot_search', 120);
    if ($search === '') {
        json_response(['ok' => false, 'error' => 'Vul een kavelnaam of plot in.'], 422);
    }
    $statement = $pdo->prepare(
        "SELECT plot_id
         FROM plots
         WHERE kavel_nummer = :exact
            OR plot_naam = :exact
            OR kavel_nummer LIKE :search
            OR plot_naam LIKE :search
         ORDER BY (kavel_nummer = :exact) DESC, (plot_naam = :exact) DESC
         LIMIT 2"
    );
    $statement->execute([
        'exact' => $search,
        'search' => '%' . $search . '%',
    ]);
    $rows = $statement->fetchAll();
    if (count($rows) !== 1) {
        json_response(['ok' => false, 'error' => count($rows) > 1 ? 'Kavelzoekterm is niet uniek. Kies de kavel uit de lijst of gebruik exact kavelnummer.' : 'Kavel/plot niet gevonden.'], 422);
    }

    return (int) $rows[0]['plot_id'];
}

function audit_history(PDO $pdo, ?int $entryId, string $action, ?array $oldValues, ?array $newValues): void
{
    $statement = $pdo->prepare(
        'INSERT INTO pwa_history_change_log
           (plot_jaar_teller_id, actor_teller_id, actor_email, action, old_values, new_values, ip, user_agent_hash)
         VALUES
           (:entry_id, :actor_teller_id, :actor_email, :action, :old_values, :new_values, :ip, :user_agent_hash)'
    );
    $statement->execute([
        'entry_id' => $entryId,
        'actor_teller_id' => $_SESSION['teller_id'] ?? null,
        'actor_email' => $_SESSION['email'] ?? null,
        'action' => $action,
        'old_values' => $oldValues === null ? null : json_encode($oldValues, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
        'new_values' => $newValues === null ? null : json_encode($newValues, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
        'ip' => ip_binary(),
        'user_agent_hash' => user_agent_hash(),
    ]);
}

try {
    require_admin();
    require_csrf();

    $action = post_input_string('action', 20);
    $pdo = db();
    $pdo->beginTransaction();

    if ($action === 'create') {
        $tellerId = resolve_teller_id($pdo);
        $plotId = resolve_plot_id($pdo);
        $jaar = post_int_value('jaar');
        if ($jaar < 1900 || $jaar > 2100) {
            json_response(['ok' => false, 'error' => 'Jaar moet tussen 1900 en 2100 liggen.'], 422);
        }
        assert_exists($pdo, 'tellers', 'id', $tellerId, 'Teller bestaat niet.');
        assert_exists($pdo, 'plots', 'plot_id', $plotId, 'Plot bestaat niet.');

        $statement = $pdo->prepare(
            'INSERT INTO plot_jaar_teller (teller_id, plot_id, jaar)
             VALUES (:teller_id, :plot_id, :jaar)'
        );
        $statement->execute(['teller_id' => $tellerId, 'plot_id' => $plotId, 'jaar' => $jaar]);
        $entryId = (int) $pdo->lastInsertId();
        $new = fetch_history_entry($pdo, $entryId);
        audit_history($pdo, $entryId, 'history_create', null, $new);
    } elseif ($action === 'update') {
        $entryId = post_int_value('id');
        $plotId = post_int_value('plot_id');
        $jaar = post_int_value('jaar');
        if ($jaar < 1900 || $jaar > 2100) {
            json_response(['ok' => false, 'error' => 'Jaar moet tussen 1900 en 2100 liggen.'], 422);
        }
        assert_exists($pdo, 'plots', 'plot_id', $plotId, 'Plot bestaat niet.');
        $old = fetch_history_entry($pdo, $entryId);
        if (!$old) {
            json_response(['ok' => false, 'error' => 'Telhistorie-regel bestaat niet.'], 404);
        }

        $statement = $pdo->prepare(
            'UPDATE plot_jaar_teller
             SET plot_id = :plot_id, jaar = :jaar
             WHERE id = :id'
        );
        $statement->execute(['plot_id' => $plotId, 'jaar' => $jaar, 'id' => $entryId]);
        $new = fetch_history_entry($pdo, $entryId);
        if ((string) $old['plot_id'] !== (string) $new['plot_id'] || (string) $old['jaar'] !== (string) $new['jaar']) {
            audit_history($pdo, $entryId, 'history_update', $old, $new);
        }
    } elseif ($action === 'delete') {
        $entryId = post_int_value('id');
        $old = fetch_history_entry($pdo, $entryId);
        if (!$old) {
            json_response(['ok' => false, 'error' => 'Telhistorie-regel bestaat niet.'], 404);
        }

        $pdo->prepare('DELETE FROM plot_jaar_teller WHERE id = :id')->execute(['id' => $entryId]);
        audit_history($pdo, $entryId, 'history_delete', $old, null);
    } else {
        json_response(['ok' => false, 'error' => 'Onbekende actie.'], 422);
    }

    $pdo->commit();
    json_response(['ok' => true, 'data' => ['id' => $entryId ?? null]]);
} catch (PDOException $error) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    if ($error->getCode() === '23000') {
        json_response(['ok' => false, 'error' => 'Deze combinatie teller, plot en jaar bestaat al of verwijst naar ontbrekende gegevens.'], 422);
    }
    handle_error($error);
} catch (Throwable $error) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    handle_error($error);
}
