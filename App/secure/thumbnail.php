<?php
require_once __DIR__ . '/secure_bootstrap.php';

$e  = $_GET['e']  ?? '';
$t  = $_GET['t']  ?? 'thumb';
$ts = $_GET['ts'] ?? '';
$f  = $_GET['f']  ?? '';
$s  = $_GET['sig']?? '';

$videoPath = sb_validate_signature($e, $t, $ts, $f, $s);
if (!$videoPath) {
    sb_json(['status'=>'error','message'=>'unauthorized or expired'],401);
}

$thumbDir = realpath(__DIR__.'/../series_images');
if ($thumbDir === false) {
    $mk = __DIR__.'/../series_images';
    if (!is_dir($mk)) mkdir($mk,0755,true);
    $thumbDir = realpath($mk);
}
$thumbFile = $thumbDir.'/thumb_'.basename($videoPath).'.jpg';

$needsGen = true;
if (is_file($thumbFile) && filesize($thumbFile) > 1024) {
    // Cache 24h
    if (time() - filemtime($thumbFile) < 86400) $needsGen = false;
}

if ($needsGen) {
    $escapedVideo = escapeshellarg($videoPath);
    $escapedOut = escapeshellarg($thumbFile);
    // capture at 3 seconds, quality 4
    $cmd = "ffmpeg -ss 3 -i $escapedVideo -frames:v 1 -q:v 4 -y $escapedOut 2>&1";
    exec($cmd, $out, $code);
    if ($code !== 0 || !is_file($thumbFile)) {
        sb_json(['status'=>'error','message'=>'thumb_generation_failed','detail'=>$out],500);
    }
}
header('Content-Type: image/jpeg');
header('Cache-Control: public, max-age=86400');
readfile($thumbFile);
