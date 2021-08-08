<?php
# rm -f /scripts/php/func_encrypt-msg.php ; nano /scripts/php/func_encrypt-msg.php

include_once "Log.php";
include "UnsafeCrypto.php";

if (!isset($_REQUEST['m'])) {
    http_response_code(400);
    LOG::writeHost("func_encrypt-msg.php", $_REQUEST['remote_addr'], "param 'm' is missing.");
    return;
}

$message = $_REQUEST['m'];
$remote_addr = $_REQUEST['remote_addr'];
header("remote-addr: $remote_addr");

if (isset($_REQUEST['h'])) {
    $remote_addr = $_REQUEST['h'];
}

$valid_ts = null;
if (isset($_REQUEST['v'])) {
    $valid = $_REQUEST['v'];
    $valid_ts = strtotime($valid);
    header("valid: " . date('F j, Y, g:i a', $valid_ts));

    $object = (object)['v' => $valid_ts, 'h' => $remote_addr, 'm' => $message];
    LOG::writeHost("func_encrypt-msg.php", $_REQUEST['remote_addr'], "ADDR: $remote_addr | VALID: $valid_ts");
} else {
    $object = (object)['h' => $remote_addr, 'm' => $message];
    LOG::writeHost("func_encrypt-msg.php", $_REQUEST['remote_addr'], "ADDR: $remote_addr");
}

$json = json_encode((array)$object);
echo UnsafeCrypto::encrypt(UnsafeCrypto::encrypt_ext(strrev($remote_addr), 'BF-ECB', $json), true);
