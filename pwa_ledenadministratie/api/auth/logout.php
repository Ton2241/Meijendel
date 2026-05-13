<?php

declare(strict_types=1);

require dirname(__DIR__) . '/bootstrap.php';

$tellerId = isset($_SESSION['teller_id']) ? (int) $_SESSION['teller_id'] : null;
$email = $_SESSION['email'] ?? null;
if ($tellerId !== null) {
    audit_auth($tellerId, $email, 'logout', 'success');
}
$_SESSION = [];
session_destroy();

json_response(['ok' => true, 'data' => ['authenticated' => false]]);
