<?php

declare(strict_types=1);

require dirname(__DIR__) . '/bootstrap.php';

try {
    $selector = post_string('selector', 32);
    $token = post_string('token', 120);
    if ($selector === '' || $token === '') {
        json_response(['ok' => false, 'error' => 'Inloglink is ongeldig.'], 422);
    }

    $rows = run_query(
        'SELECT * FROM pwa_magic_link_challenges WHERE selector = :selector LIMIT 1',
        ['selector' => $selector]
    );
    $challenge = $rows[0] ?? null;
    if (!$challenge) {
        audit_auth(null, null, 'auth_failed', 'denied', null, ['reason' => 'unknown_selector']);
        json_response(['ok' => false, 'error' => 'Inloglink is ongeldig.'], 401);
    }

    $challengeId = (int) $challenge['id'];
    $tellerId = (int) $challenge['teller_id'];
    $email = (string) $challenge['email'];
    if ($challenge['consumed_at'] !== null) {
        audit_auth($tellerId, $email, 'magic_link_verified', 'consumed', $challengeId);
        json_response(['ok' => false, 'error' => 'Deze inloglink is al gebruikt. Vraag een nieuwe link aan.'], 401);
    }
    if (strtotime((string) $challenge['expires_at']) < time()) {
        audit_auth($tellerId, $email, 'magic_link_verified', 'expired', $challengeId);
        json_response(['ok' => false, 'error' => 'Deze inloglink is verlopen. Vraag een nieuwe link aan.'], 401);
    }
    if (!hash_equals((string) $challenge['token_hash'], token_hash($token))) {
        audit_auth($tellerId, $email, 'magic_link_verified', 'denied', $challengeId);
        json_response(['ok' => false, 'error' => 'Inloglink is ongeldig.'], 401);
    }

    $reasons = [];
    $requestedCountry = $challenge['requested_country_code'];
    if ($requestedCountry !== null && country_code() !== null && country_code() !== $requestedCountry) {
        $reasons[] = 'country';
    }
    if ($challenge['requested_user_agent_family'] !== null && user_agent_family() !== $challenge['requested_user_agent_family']) {
        $reasons[] = 'device';
    }
    if ($reasons && !whitelist_matches($tellerId, $email)) {
        $reason = implode(',', $reasons);
        db()->prepare(
            'UPDATE pwa_magic_link_challenges
             SET confirmation_required = 1, soft_mismatch_reason = :reason
             WHERE id = :id'
        )->execute(['reason' => $reason, 'id' => $challengeId]);
        audit_auth($tellerId, $email, 'soft_check_mismatch', 'pending', $challengeId, ['reason' => $reason]);
        audit_auth($tellerId, $email, 'extra_confirmation_required', 'pending', $challengeId);
        json_response([
            'ok' => false,
            'error' => 'Nieuwe locatie of apparaat. Vul de fallbackcode uit de e-mail in.',
            'needs_code' => true,
            'email' => $email,
        ], 403);
    }

    db()->prepare('UPDATE pwa_magic_link_challenges SET consumed_at = NOW() WHERE id = :id')
        ->execute(['id' => $challengeId]);
    start_authenticated_session($tellerId, $email);
    audit_auth($tellerId, $email, 'magic_link_verified', 'success', $challengeId);

    json_response(['ok' => true, 'data' => ['authenticated' => true]]);
} catch (Throwable $error) {
    handle_error($error);
}
