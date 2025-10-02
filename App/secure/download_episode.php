<?php
require_once __DIR__ . '/secure_bootstrap.php';

$e  = $_GET['e']  ?? '';
$t  = $_GET['t']  ?? 'download';
$ts = $_GET['ts'] ?? '';
$f  = $_GET['f']  ?? '';
$s  = $_GET['sig']?? '';

$path = sb_validate_signature($e, $t, $ts, $f, $s);
if (!$path) {
    sb_json(['status'=>'error','message'=>'unauthorized or expired'], 401);
}
$size = filesize($path);
$ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
$mime = 'application/octet-stream';
if (in_array($ext,['mp4','mkv','mov','webm','avi'])) $mime='video/'.($ext==='mkv'?'x-matroska':$ext);

header('Content-Type: '.$mime);
header('Content-Disposition: attachment; filename="'.basename($path).'"');
header('Content-Length: '.$size);
header('Accept-Ranges: none');
readfile($path);
