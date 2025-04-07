<?php

# http://localhost:8338/local/resource.json?share

# ./scripts/docker-exec.sh bash
# rm /scripts/php/decrypt-link.php ; nano /scripts/php/decrypt-link.php
# tail -f /tmp/php.log

include_once "Log.php";
include "common_functions.php";
include "Crypto.php";
include "UptoDate.php";

denyAccessFromExternal("decrypt-link.php");

$time_start = microtime(true);

$uri = $_REQUEST['uri'];
$remote_addr = $_REQUEST['remote_addr'];

$found = preg_match('/\/decrypt-link\/(.*)\/(.*)/', $uri, $matches);
if (!$found) {
    http_response_code(400);
    LOG::writeTime("decrypt-link.php", $remote_addr, "Error: could not parse cipher and filename from $uri", $time_start);
    exit;
}

$encrypted = $matches[1];
$filename = $matches[2];
$decrypted = Crypto::decrypt($encrypted, true);

$object = json_decode($decrypted);

$name = basename($object->uri);
if ($name != $filename) {
    http_response_code(400);
    LOG::writeTime("decrypt-link.php",$remote_addr,"Error: expected filename mismatch -> $filename is not correct (expect $name)", $time_start);
    exit;
}
header('Content-Type: application/json; charset=utf-8');
echo "{\"path\": \"$object->uri\"}";

LOG::writeTime("decrypt-link.php",$remote_addr,"processed link", $time_start);

