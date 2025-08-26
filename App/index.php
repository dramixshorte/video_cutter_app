<?php
// منع الوصول المباشر
if (!isset($_SERVER['HTTP_USER_AGENT']) || strpos($_SERVER['HTTP_USER_AGENT'], 'okhttp') === false) {
    http_response_code(403);
    exit('Access denied.');
}
?>
