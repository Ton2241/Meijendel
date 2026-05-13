<?php

declare(strict_types=1);

require dirname(__DIR__) . '/bootstrap.php';

try {
    $email = strtolower(post_string('email'));
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        json_response(['ok' => false, 'error' => 'Vul een geldig e-mailadres in.'], 422);
    }

    $teller = find_teller_by_email($email);
    if (!$teller) {
        audit_auth(null, $email, 'magic_link_requested', 'denied');
        json_response(['ok' => true, 'data' => ['message' => 'Als dit e-mailadres bekend is, is een inloglink verstuurd.']]);
    }

    $selector = bin2hex(random_bytes(16));
    $token = random_url_token(32);
    $code = (string) random_int(100000, 999999);
    $config = app_config();
    $ttl = max(5, (int) ($config['auth']['magic_link_ttl_minutes'] ?? 15));
    $maxCodeAttempts = min(10, max(1, (int) ($config['auth']['max_code_attempts'] ?? 5)));

    $statement = db()->prepare(
        'INSERT INTO pwa_magic_link_challenges
           (teller_id, email, selector, token_hash, code_hash, max_code_attempts,
            requested_ip, requested_country_code, requested_user_agent_family, requested_user_agent_hash, expires_at)
         VALUES
           (:teller_id, :email, :selector, :token_hash, :code_hash, :max_code_attempts,
            :requested_ip, :requested_country_code, :requested_user_agent_family, :requested_user_agent_hash,
            DATE_ADD(NOW(), INTERVAL :ttl MINUTE))'
    );
    $statement->execute([
        'teller_id' => (int) $teller['id'],
        'email' => $email,
        'selector' => $selector,
        'token_hash' => token_hash($token),
        'code_hash' => password_hash($code, PASSWORD_DEFAULT),
        'max_code_attempts' => $maxCodeAttempts,
        'requested_ip' => ip_binary(),
        'requested_country_code' => country_code(),
        'requested_user_agent_family' => user_agent_family(),
        'requested_user_agent_hash' => user_agent_hash(),
        'ttl' => $ttl,
    ]);
    $challengeId = (int) db()->lastInsertId();
    audit_auth((int) $teller['id'], $email, 'magic_link_requested', 'success', $challengeId);

    $baseUrl = rtrim((string) ($config['app']['base_url'] ?? ''), '/');
    $link = $baseUrl . '/?selector=' . rawurlencode($selector) . '&token=' . rawurlencode($token);
    $subject = 'Inloggen op VWG-M ledenadministratie';
    $body = "Beste " . ($teller['naam'] ?: 'VWG-M gebruiker') . ",\n\n"
        . "Gebruik deze eenmalige link om in te loggen:\n$link\n\n"
        . "Fallbackcode: $code\n\n"
        . "De link en code verlopen over $ttl minuten. Heb je dit niet aangevraagd, negeer dit bericht.\n";
    $sent = send_app_mail($email, $subject, $body);

    audit_auth((int) $teller['id'], $email, 'magic_link_sent', $sent ? 'success' : 'denied', $challengeId);
    if (!$sent) {
        json_response(['ok' => false, 'error' => 'De inlogmail kon niet worden verstuurd. Controleer de mailconfiguratie.'], 500);
    }

    json_response(['ok' => true, 'data' => ['message' => 'Als dit e-mailadres bekend is, is een inloglink verstuurd.']]);
} catch (Throwable $error) {
    handle_error($error);
}
