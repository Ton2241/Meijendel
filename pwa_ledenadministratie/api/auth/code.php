<?php

declare(strict_types=1);

require dirname(__DIR__) . '/bootstrap.php';

try {
    $email = strtolower(post_string('email'));
    $code = post_string('code', 12);
    if (!filter_var($email, FILTER_VALIDATE_EMAIL) || !preg_match('/^\d{6}$/', $code)) {
        json_response(['ok' => false, 'error' => 'Vul e-mailadres en zescijferige code in.'], 422);
    }

    $rows = run_query(
        'SELECT *
         FROM pwa_magic_link_challenges
         WHERE LOWER(email) = LOWER(:email)
           AND consumed_at IS NULL
           AND expires_at >= NOW()
         ORDER BY created_at DESC
         LIMIT 1',
        ['email' => $email]
    );
    $challenge = $rows[0] ?? null;
    if (!$challenge) {
        audit_auth(null, $email, 'magic_code_verified', 'expired');
        json_response(['ok' => false, 'error' => 'Geen geldige code gevonden. Vraag een nieuwe inloglink aan.'], 401);
    }

    $challengeId = (int) $challenge['id'];
    $tellerId = (int) $challenge['teller_id'];
    if ((int) $challenge['code_attempts'] >= (int) $challenge['max_code_attempts']) {
        audit_auth($tellerId, $email, 'magic_code_verified', 'denied', $challengeId, ['reason' => 'too_many_attempts']);
        json_response(['ok' => false, 'error' => 'Te veel codepogingen. Vraag een nieuwe inloglink aan.'], 429);
    }

    db()->prepare('UPDATE pwa_magic_link_challenges SET code_attempts = code_attempts + 1 WHERE id = :id')
        ->execute(['id' => $challengeId]);

    if (!password_verify($code, (string) $challenge['code_hash'])) {
        audit_auth($tellerId, $email, 'magic_code_verified', 'denied', $challengeId);
        json_response(['ok' => false, 'error' => 'Code is ongeldig.'], 401);
    }

    db()->prepare('UPDATE pwa_magic_link_challenges SET consumed_at = NOW() WHERE id = :id')
        ->execute(['id' => $challengeId]);
    start_authenticated_session($tellerId, $email);
    audit_auth($tellerId, $email, 'magic_code_verified', 'success', $challengeId);

    json_response(['ok' => true, 'data' => ['authenticated' => true]]);
} catch (Throwable $error) {
    handle_error($error);
}
