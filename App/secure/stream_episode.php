<?php
require_once __DIR__ . '/secure_bootstrap.php';

$e  = $_GET['e']  ?? '';
$t  = $_GET['t']  ?? 'stream';
$ts = $_GET['ts'] ?? '';
$f  = $_GET['f']  ?? '';
$s  = $_GET['sig']?? '';

$path = sb_validate_signature($e, $t, $ts, $f, $s);
if (!$path) {
    sb_json(['status'=>'error','message'=>'unauthorized or expired'], 401);
}

$size = filesize($path);
$fp = fopen($path, 'rb');
if (!$fp) sb_json(['status'=>'error','message'=>'file_open_failed'],500);

$ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
$mime = 'video/mp4';
if (in_array($ext,['mkv'])) $mime='video/x-matroska';
elseif (in_array($ext,['webm'])) $mime='video/webm';

header('Content-Type: '.$mime);
header('Accept-Ranges: bytes');

$rangeHeader = $_SERVER['HTTP_RANGE'] ?? '';
if ($rangeHeader && preg_match('/bytes=(\d+)-(\d*)/',$rangeHeader,$m)) {
    $start = (int)$m[1];
    $end = ($m[2] !== '') ? (int)$m[2] : ($size - 1);
    if ($start > $end || $end >= $size) {
        header('HTTP/1.1 416 Requested Range Not Satisfiable');
        header('Content-Range: bytes */'.$size);
        fclose($fp);exit;
    }
    $length = $end - $start + 1;
    header('HTTP/1.1 206 Partial Content');
    header("Content-Range: bytes $start-$end/$size");
    header('Content-Length: '.$length);
    fseek($fp, $start);
    $remaining = $length;
    while ($remaining > 0 && !feof($fp)) {
        $chunk = fread($fp, min(8192,$remaining));
        echo $chunk;
        $remaining -= strlen($chunk);
        if ($remaining <= 0) break;
    }
    fclose($fp);exit;
}

header('Content-Length: '.$size);
while (!feof($fp)) {
    echo fread($fp,8192);
}
fclose($fp);
