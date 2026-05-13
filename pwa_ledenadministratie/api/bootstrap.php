<?php

declare(strict_types=1);

$config = app_config();
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => (bool) ($config['auth']['cookie_secure'] ?? true),
    'httponly' => true,
    'samesite' => 'Lax',
]);
session_name('vwgm_pwa_session');
session_start();

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function app_config(): array
{
    $localConfig = dirname(__DIR__) . '/config.php';
    $exampleConfig = dirname(__DIR__) . '/config.example.php';

    return require is_file($localConfig) ? $localConfig : $exampleConfig;
}

function db(): PDO
{
    static $pdo = null;

    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $config = app_config()['db'];
    $dsn = sprintf(
        'mysql:host=%s;port=%d;dbname=%s;charset=%s',
        $config['host'],
        $config['port'],
        $config['database'],
        $config['charset']
    );

    $pdo = new PDO($dsn, $config['user'], $config['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);

    return $pdo;
}

function auth_enabled(): bool
{
    return (bool) (app_config()['auth']['enabled'] ?? true);
}

function client_ip(): string
{
    $header = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? '';
    $ip = trim(explode(',', $header)[0]);

    return filter_var($ip, FILTER_VALIDATE_IP) ? $ip : '0.0.0.0';
}

function country_code(): ?string
{
    $value = strtoupper(trim((string) ($_SERVER['HTTP_CF_IPCOUNTRY'] ?? $_SERVER['HTTP_X_APP_COUNTRY'] ?? '')));

    return preg_match('/^[A-Z]{2}$/', $value) ? $value : null;
}

function user_agent_family(): string
{
    $ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
    $browser = 'Other';
    foreach (['Edg' => 'Edge', 'Chrome' => 'Chrome', 'Firefox' => 'Firefox', 'Safari' => 'Safari'] as $needle => $label) {
        if (stripos($ua, $needle) !== false) {
            $browser = $label;
            break;
        }
    }

    $os = 'Other';
    foreach (['Windows' => 'Windows', 'Mac OS X' => 'macOS', 'iPhone' => 'iOS', 'iPad' => 'iPadOS', 'Android' => 'Android', 'Linux' => 'Linux'] as $needle => $label) {
        if (stripos($ua, $needle) !== false) {
            $os = $label;
            break;
        }
    }

    return $browser . '/' . $os;
}

function user_agent_hash(): string
{
    return hash('sha256', $_SERVER['HTTP_USER_AGENT'] ?? '');
}

function ip_binary(?string $ip = null): ?string
{
    $packed = inet_pton($ip ?? client_ip());

    return $packed === false ? null : $packed;
}

function random_url_token(int $bytes = 32): string
{
    return rtrim(strtr(base64_encode(random_bytes($bytes)), '+/', '-_'), '=');
}

function token_hash(string $value): string
{
    return hash('sha256', $value);
}

function post_string(string $key, int $maxLength = 255): string
{
    $value = trim((string) ($_POST[$key] ?? ''));

    return substr($value, 0, $maxLength);
}

function find_teller_by_email(string $email): ?array
{
    $statement = db()->prepare(
        "SELECT id, email,
                TRIM(CONCAT_WS(' ', NULLIF(voornaam, ''), NULLIF(tussenvoegsel, ''), NULLIF(achternaam, ''))) AS naam
         FROM tellers
         WHERE LOWER(email) = LOWER(:email)
         LIMIT 1"
    );
    $statement->execute(['email' => $email]);
    $row = $statement->fetch();

    return $row ?: null;
}

function cidr_contains(string $cidr, string $ip): bool
{
    if (!str_contains($cidr, '/')) {
        return $cidr === $ip;
    }
    [$network, $prefix] = explode('/', $cidr, 2);
    $networkPacked = inet_pton($network);
    $ipPacked = inet_pton($ip);
    if ($networkPacked === false || $ipPacked === false || strlen($networkPacked) !== strlen($ipPacked)) {
        return false;
    }
    $bits = (int) $prefix;
    $bytes = intdiv($bits, 8);
    $remainder = $bits % 8;
    if ($bytes > 0 && substr($networkPacked, 0, $bytes) !== substr($ipPacked, 0, $bytes)) {
        return false;
    }
    if ($remainder === 0) {
        return true;
    }
    $mask = chr((0xff << (8 - $remainder)) & 0xff);

    return ($networkPacked[$bytes] & $mask) === ($ipPacked[$bytes] & $mask);
}

function whitelist_matches(int $tellerId, string $email): bool
{
    $rows = run_query('SELECT * FROM pwa_auth_whitelist WHERE active = 1');
    $ip = client_ip();
    $country = country_code();
    $uaFamily = user_agent_family();

    foreach ($rows as $row) {
        if ($row['teller_id'] !== null && (int) $row['teller_id'] !== $tellerId) {
            continue;
        }
        if ($row['email'] !== null && strcasecmp((string) $row['email'], $email) !== 0) {
            continue;
        }
        if ($row['country_code'] !== null && $country !== strtoupper((string) $row['country_code'])) {
            continue;
        }
        if ($row['user_agent_family'] !== null && $uaFamily !== (string) $row['user_agent_family']) {
            continue;
        }
        if ($row['ip_cidr'] !== null && !cidr_contains((string) $row['ip_cidr'], $ip)) {
            continue;
        }
        audit_auth($tellerId, $email, 'whitelist_match', 'success', null, ['whitelist_id' => $row['id']]);

        return true;
    }

    return false;
}

function start_authenticated_session(int $tellerId, string $email): void
{
    session_regenerate_id(true);
    $_SESSION['teller_id'] = $tellerId;
    $_SESSION['email'] = $email;
    $_SESSION['authenticated_at'] = time();
}

function smtp_read($socket): string
{
    $response = '';
    while (($line = fgets($socket, 515)) !== false) {
        $response .= $line;
        if (strlen($line) >= 4 && $line[3] === ' ') {
            break;
        }
    }

    return $response;
}

function smtp_command($socket, string $command, array $okCodes): string
{
    fwrite($socket, $command . "\r\n");
    $response = smtp_read($socket);
    if (!in_array(substr($response, 0, 3), $okCodes, true)) {
        throw new RuntimeException('SMTP-fout bij commando: ' . strtok($command, ' '));
    }

    return $response;
}

function send_app_mail(string $to, string $subject, string $body): bool
{
    $mail = app_config()['mail'];
    if (($mail['smtp_host'] ?? '') === '') {
        $headers = ['From: ' . $mail['from']];
        $returnPath = (string) ($mail['return_path'] ?? '');

        return $returnPath !== ''
            ? mail($to, $subject, $body, implode("\r\n", $headers), '-f' . escapeshellarg($returnPath))
            : mail($to, $subject, $body, implode("\r\n", $headers));
    }

    $host = (string) $mail['smtp_host'];
    $port = (int) ($mail['smtp_port'] ?? 587);
    $secure = (string) ($mail['smtp_secure'] ?? 'tls');
    $target = $secure === 'ssl' ? 'ssl://' . $host : $host;
    $socket = stream_socket_client($target . ':' . $port, $errno, $errstr, 10, STREAM_CLIENT_CONNECT);
    if (!$socket) {
        throw new RuntimeException('SMTP-verbinding mislukt: ' . $errstr);
    }
    stream_set_timeout($socket, 10);
    smtp_read($socket);
    smtp_command($socket, 'EHLO app.vwg-m.nl', ['250']);
    if ($secure === 'tls') {
        smtp_command($socket, 'STARTTLS', ['220']);
        stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT);
        smtp_command($socket, 'EHLO app.vwg-m.nl', ['250']);
    }
    if (($mail['smtp_user'] ?? '') !== '') {
        smtp_command($socket, 'AUTH LOGIN', ['334']);
        smtp_command($socket, base64_encode((string) $mail['smtp_user']), ['334']);
        smtp_command($socket, base64_encode((string) $mail['smtp_password']), ['235']);
    }

    $from = (string) $mail['from'];
    smtp_command($socket, 'MAIL FROM:<' . $from . '>', ['250']);
    smtp_command($socket, 'RCPT TO:<' . $to . '>', ['250', '251']);
    smtp_command($socket, 'DATA', ['354']);
    $headers = [
        'From: ' . $from,
        'To: ' . $to,
        'Subject: ' . $subject,
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
        'Content-Transfer-Encoding: 8bit',
    ];
    fwrite($socket, implode("\r\n", $headers) . "\r\n\r\n" . str_replace("\n.", "\n..", $body) . "\r\n.\r\n");
    $response = smtp_read($socket);
    smtp_command($socket, 'QUIT', ['221']);
    fclose($socket);

    return substr($response, 0, 3) === '250';
}

function audit_auth(?int $tellerId, ?string $email, string $eventType, string $result, ?int $challengeId = null, array $details = []): void
{
    $statement = db()->prepare(
        'INSERT INTO pwa_auth_audit_log
           (teller_id, email, event_type, result, ip, country_code, user_agent_family, user_agent_hash, challenge_id, details)
         VALUES
           (:teller_id, :email, :event_type, :result, :ip, :country_code, :user_agent_family, :user_agent_hash, :challenge_id, :details)'
    );
    $statement->execute([
        'teller_id' => $tellerId,
        'email' => $email,
        'event_type' => $eventType,
        'result' => $result,
        'ip' => ip_binary(),
        'country_code' => country_code(),
        'user_agent_family' => user_agent_family(),
        'user_agent_hash' => user_agent_hash(),
        'challenge_id' => $challengeId,
        'details' => json_encode($details, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
    ]);
}

function require_auth(): void
{
    if (!auth_enabled()) {
        return;
    }
    if (!empty($_SESSION['teller_id'])) {
        return;
    }

    json_response(['ok' => false, 'error' => 'Inloggen vereist.'], 401);
}

function input_string(string $key, int $maxLength = 100): string
{
    $value = trim((string) ($_GET[$key] ?? ''));
    return substr($value, 0, $maxLength);
}

function input_int(string $key): ?int
{
    $value = trim((string) ($_GET[$key] ?? ''));
    if ($value === '' || !preg_match('/^\d{4}$/', $value)) {
        return null;
    }

    return (int) $value;
}

function json_response(array $payload, int $status = 200): void
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function run_query(string $sql, array $params = []): array
{
    $statement = db()->prepare($sql);
    $statement->execute($params);

    return $statement->fetchAll();
}

function handle_error(Throwable $error): void
{
    $payload = [
        'ok' => false,
        'error' => 'De ledenadministratie kon de gegevens niet laden.',
    ];

    if (getenv('APP_DEBUG') === '1') {
        $payload['detail'] = $error->getMessage();
    }

    json_response($payload, 500);
}

$publicEndpoints = ['request.php', 'verify.php', 'code.php', 'status.php'];
$path = str_replace('\\', '/', $_SERVER['SCRIPT_NAME'] ?? '');
if (auth_enabled() && !str_contains($path, '/api/auth/') && !in_array(basename($path), $publicEndpoints, true)) {
    require_auth();
}
