<?php
// Shared security bootstrap for signed episode delivery
// IMPORTANT: Replace this key with a long random string and keep it out of VCS in production.
const SECURE_EPISODES_SECRET = 'CHANGE_ME_TO_A_LONG_RANDOM_SECRET_64_CHARS_MIN';

function sb_json($data, int $code = 200): void {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

/**
 * Validates incoming signed parameters and returns absolute path to episode file if valid.
 */
function sb_validate_signature(string $episodeId, string $type, string $ts, string $file, string $sig): ?string {
    if ($episodeId === '' || $type === '' || $ts === '' || $file === '' || $sig === '') return null;
    if (!ctype_digit($episodeId)) return null;
    if (!ctype_digit($ts)) return null;
    $expiry = (int)$ts;
    if ($expiry < time()) return null; // expired

    // Basic allowlist for type
    if (!in_array($type, ['stream','download','thumb'], true)) return null;

    // Sanitize filename
    $safeFile = basename($file);
    if ($safeFile === '' || strpos($safeFile, '..') !== false) return null;

    $episodeDir = realpath(__DIR__ . '/../series_episodes');
    if ($episodeDir === false) return null;
    $target = realpath($episodeDir . '/' . $safeFile);
    if ($target === false || strpos($target, $episodeDir) !== 0 || !is_file($target)) return null;

    $calc = hash_hmac('sha256', $episodeId . '|' . $type . '|' . $ts . '|' . $safeFile, SECURE_EPISODES_SECRET);
    if (!hash_equals($calc, $sig)) return null;

    return $target;
}

function sb_emit_cor_headers(): void {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, HEAD, OPTIONS');
    header('Access-Control-Allow-Headers: Range, Accept, Origin, Content-Type');
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    sb_emit_cor_headers();
    http_response_code(200);
    exit;
}

sb_emit_cor_headers();
