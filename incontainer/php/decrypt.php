<?php

# rm /scripts/php/decrypt.php ; nano /scripts/php/decrypt.php
# ./scripts/docker-exec.sh bash
# tail -f /tmp/php.log

include_once "Log.php";
include "common_functions.php";
include "UnsafeCrypto.php";
include "UptoDate.php";

denyAccessFromExternal("decrypt.php");

$time_start = microtime(true);

$uri = $_REQUEST['uri'];
$remote_addr = $_REQUEST['remote_addr'];

$found = preg_match('/\/decrypt\/(.*)\/(.*)/', $uri, $matches);
if (!$found) {
    http_response_code(400);
    LOG::writeTime("decrypt.php", $remote_addr, "Error: could not parse cipher and filename from $uri", $time_start);
    exit;
}

$encrypted = $matches[1];
$decrypted = UnsafeCrypto::decrypt($encrypted, true);

$object = json_decode($decrypted);

# cache == false
$url = "http://127.0.0.1".$object->uri;
$cacheStatus = "NO-CACHE";

if ($object->cache == "true") {
    $uptoDate = new UptoDate($object->uri);
    $url = $uptoDate->url(true);
    $cacheStatus = $uptoDate->cacheStatus;
}
$name = basename($object->uri);
$filename = $matches[2];

if ($name != $filename) {
    echo "Error: expected filename mismatch -> $filename is not correct";
    LOG::writeTime("decrypt.php",$remote_addr,"Error: expected filename mismatch -> $filename is not correct (expect $name)", $time_start);
    exit;
}

$encodedName = rawurlencode($name);
if ($encodedName != $name) {
    $url = str_replace($name,$encodedName,$url);
}

# from common_functions.php
$res = forwardRequest($url);
$forwaredUrlPath = parse_url($url, PHP_URL_PATH);

LOG::writeTime("decrypt.php", $remote_addr, "processed $forwaredUrlPath | Length: {$res['Content-Length']} | Cache: $cacheStatus", $time_start);
