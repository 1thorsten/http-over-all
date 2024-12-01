<?php

# rm -f /scripts/php/latest.php ; nano /scripts/php/latest.php
# ./scripts/docker-exec.sh bash
# tail -f /tmp/php.log
include_once "globals.php";
include_once "Log.php";
include "common_functions.php";
include "UptoDate.php";

if (PHP_LOG_ENABLED) {
    $debug = var_export($_SERVER, true);
    LOG::write("latest.php", "server-header: $debug");
}
# common_functions.php
denyAccessFromExternal("latest.php");

$time_start = microtime(true);

$path = $_REQUEST['uri'];
$remote_addr = $_REQUEST['remote_addr'];

$uptoDate = new UptoDate($path);
# $uptoDate->cleanUpCache();
$url = $uptoDate->url(true);
if (strstr($uptoDate->lastHttpStatus,'301') === '301 Moved Permanently') {
    header("Location: $path/");
    LOG::writeTime("latest.php", $remote_addr, "redirect to $path/ [$uptoDate->lastHttpStatus]", $time_start);
    exit();
}

$log = (PHP_LOG_ENABLED === "true");
$debugOut = '';
if (isset($_SERVER['HTTP_X_DEBUG_OUT'])) {
    $log = true;
    $debugOut = "| Debug: {$_SERVER['HTTP_X_DEBUG_OUT']} ";
}

$requestMethod = $_SERVER['REQUEST_METHOD'];
if ($requestMethod == "HEAD") {
    header('Content-Type: ' . $uptoDate->resourceHeaders['Content-Type']);
    header('Content-Length: ' . $uptoDate->resourceHeaders['Content-Length']);
    header('Last-Modified: ' . $uptoDate->resourceHeaders['Last-Modified']);
    header('User-Agent: latest.php');
    header('ETag: ' . $uptoDate->resourceHeaders['ETag']);
    if ($log) {
        LOG::writeTime("latest.php", $remote_addr, "HEAD $path $debugOut| Last-Modified: {$uptoDate->resourceHeaders['Last-Modified']}", $time_start);
    }
    exit();
}

$encoded_url = preg_replace_callback('#://([^/]+)/([^?]+)#', function ($match) {
    return '://' . $match[1] . '/' . join('/', array_map('rawurlencode', explode('/', $match[2])));
}, $url);
# common_functions.php
$res = forwardRequest($encoded_url);
$forwaredUrlPath = parse_url($encoded_url, PHP_URL_PATH);
if (PHP_LOG_ENABLED) {
    LOG::writeTime("latest.php", $remote_addr, "processed $forwaredUrlPath $debugOut | Length: {$res['Content-Length']} | Cache: $uptoDate->cacheStatus", $time_start);
}
