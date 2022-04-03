<?php
# rm -f /scripts/php/func_encrypt-msg.php ; nano /scripts/php/func_encrypt-msg.php

include_once "Log.php";
include "UnsafeCrypto.php";

$remote_addr = $_REQUEST['remote_addr'];
$message = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $message = file_get_contents('php://input');
} else if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_REQUEST['m'])) {
    $message = $_REQUEST['m'];
}

if ($message === null) {
    http_response_code(400);
    LOG::writeHost("func_encrypt-msg.php", $remote_addr, "param 'm' is missing.");
    return;
}
header('Content-Type: text/plain; charset=utf-8');

$encrypt_for_hosts = false;
if (isset($_REQUEST['h'])) {
    $remote_addr = $_REQUEST['h'];
    if (filter_var($remote_addr, FILTER_VALIDATE_IP)) {
        header("Remote-addr: $remote_addr");
    } else {
        // encryption with global CRYPT_KEY and validate after decryption whether the host is allowed or not
        $encrypt_for_hosts = true;
        header("For-hosts: $remote_addr");
    }
}

$valid_ts = null;
if (isset($_REQUEST['v'])) {
    $valid = $_REQUEST['v'];
    $valid_ts = strtotime($valid);
    header("Valid: " . date('F j, Y, g:i a', $valid_ts));

    $object = (object)['v' => $valid_ts, 'h' => $remote_addr, 'm' => $message];
    LOG::writeHost("func_encrypt-msg.php", $_REQUEST['remote_addr'], "HOST: $remote_addr | VALID: $valid_ts");
} else {
    $object = (object)['h' => $remote_addr, 'm' => $message];
    LOG::writeHost("func_encrypt-msg.php", $_REQUEST['remote_addr'], "HOST: $remote_addr");
}

$json = json_encode((array)$object);
$cipher_algo = 'BF-OFB';

$encrypted = $encrypt_for_hosts ?
    UnsafeCrypto::encrypt($json, true) :
    UnsafeCrypto::encrypt_ext(strrev($remote_addr), $cipher_algo, $json, true);

echo $encrypted;
