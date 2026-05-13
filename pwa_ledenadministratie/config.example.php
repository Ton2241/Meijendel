<?php

$env = static function (string $name, string $default): string {
    $value = getenv($name);

    return $value === false ? $default : $value;
};

return [
    'app' => [
        'base_url' => $env('APP_BASE_URL', 'https://app.vwg-m.nl'),
    ],
    'db' => [
        'host' => $env('MEIJENDEL_DB_HOST', '127.0.0.1'),
        'port' => (int) $env('MEIJENDEL_DB_PORT', '3306'),
        'database' => $env('MEIJENDEL_DB_NAME', 'meijendel'),
        'user' => $env('MEIJENDEL_DB_USER', 'root'),
        'password' => $env('MEIJENDEL_DB_PASSWORD', ''),
        'charset' => 'utf8mb4',
    ],
    'auth' => [
        'enabled' => $env('AUTH_ENABLED', '1') === '1',
        'magic_link_ttl_minutes' => (int) $env('MAGIC_LINK_TTL_MINUTES', '15'),
        'max_code_attempts' => (int) $env('MAGIC_CODE_MAX_ATTEMPTS', '5'),
        'cookie_secure' => $env('COOKIE_SECURE', '1') === '1',
    ],
    'mail' => [
        'from' => $env('MAIL_FROM', 'noreply@app.vwg-m.nl'),
        'return_path' => $env('MAIL_RETURN_PATH', ''),
        'smtp_host' => $env('SMTP_HOST', ''),
        'smtp_port' => (int) $env('SMTP_PORT', '587'),
        'smtp_user' => $env('SMTP_USER', ''),
        'smtp_password' => $env('SMTP_PASSWORD', ''),
        'smtp_secure' => $env('SMTP_SECURE', 'tls'),
    ],
];
