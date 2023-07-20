<?php

# rm -f /scripts/php/force-update.php ; nano /scripts/php/force-update.php
include_once "globals.php";
include_once "Log.php";
include "common_functions.php";

# http://localhost:8338/php/force-update.php
# http://localhost:8338/force-update/
# http://10.10.0.141:8338/force-update
# http://10.20.1.122:8338/force-update

const CONNECTED_USER_AGENT = "CONNECTED_FORCE_UPDATE";
const CONNECTED_TIMEOUT_SECS = 25;

$time_start = microtime(true);
$remote_addr = $_REQUEST['remote_addr'] ?? $_SERVER['REMOTE_ADDR'];

$callForceUpdate = true;
$forcUpdateLock = is_int(FORCE_UPDATE_LOCK) ? FORCE_UPDATE_LOCK : 16;
$cmdOutput = "";
if (file_exists("/var/run/force-update.last")) {
    $file_mtime = filemtime("/var/run/force-update.last");
    list($usec, $sec) = explode(" ", microtime());
    if ($sec - $file_mtime <= $forcUpdateLock) {
        $cmdOutput = "avoid executing force-update.sh (previous call was " . ($sec - $file_mtime) . " second(s) ago; lock_sec: $forcUpdateLock)";
        LOG::write("force-update.php", $cmdOutput);
        $callForceUpdate = false;
    }
}

$curlHandles = initForceUpdateOnConnectedServers($remote_addr);

if ($callForceUpdate === true) {
    $cmdOutput = shell_exec('sudo /scripts/force-update.sh 2>&1');
}

runForceUpdateOnConnectedServers($curlHandles, $remote_addr);

if (accessFromBrowser()) {
    echo "<pre>$cmdOutput</pre>";
} else if ($callForceUpdate) {
    LOG::write("force-update.php", "CMD: /scripts/force-update.sh\n" . rtrim($cmdOutput));
}

$debugOut = '';
if (isset($_SERVER['HTTP_X_DEBUG_OUT'])) {
    $debugOut = "| Debug: {$_SERVER['HTTP_X_DEBUG_OUT']}";
}

LOG::writeTime("force-update.php", $remote_addr, "call force-update.sh $debugOut", $time_start);

function initForceUpdateOnConnectedServers($addr): ?object
{
    $agent = $_SERVER['HTTP_USER_AGENT'] ?? "";
    if ($agent === CONNECTED_USER_AGENT) {
        LOG::write("force-update.php", "connected-mode: detect master rq (UA:$agent) from $addr");
        return null;
    }

    if (empty(CONNECTED_URLS)) {
        return null;
    }

    $connected = explode(",", CONNECTED_URLS);
#    $connected = explode(",", "http://172.16.3.7:18338/force-update");
    $curlHandles = (object)[];
    $curlHandles->multiHandle = curl_multi_init();
    $curlHandles->list = array();
    foreach ($connected as $calling_url) {
        LOG::write("force-update.php", "connected-mode: init for ${calling_url} (timeout:" . CONNECTED_TIMEOUT_SECS . "s)");
        $ch = curl_init();
        $curlHandles->list[] = $ch;
        curl_setopt($ch, CURLOPT_URL, $calling_url);
        curl_setopt($ch, CURLOPT_USERAGENT, CONNECTED_USER_AGENT);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, 0);
        curl_setopt($ch, CURLOPT_TIMEOUT, CONNECTED_TIMEOUT_SECS);
        curl_multi_add_handle($curlHandles->multiHandle, $ch);
    }
    return $curlHandles;
}

function runForceUpdateOnConnectedServers($curlHandles, $addr)
{
    if ($curlHandles === null) {
        return;
    }

    $rnd = rand(1, 1000);
    $active = null;
    $time_start = microtime(true);
    //execute the handles
    do {
        $mrc = curl_multi_exec($curlHandles->multiHandle, $active);
        LOG::write("force-update.php", "connected-mode[$rnd]: curl_multi_exec (init) -> status:$mrc");
    } while ($mrc == CURLM_CALL_MULTI_PERFORM);

    while ($active && $mrc == CURLM_OK) {
        if (curl_multi_select($curlHandles->multiHandle) != -1) {
            do {
                $mrc = curl_multi_exec($curlHandles->multiHandle, $active);
            } while ($mrc == CURLM_CALL_MULTI_PERFORM);
        }
    }
    LOG::writeTime("force-update.php", $addr, "connected-mode[$rnd]: curl_multi_exec", $time_start);

    foreach ($curlHandles->list as $ch) {
        curl_multi_remove_handle($curlHandles->multiHandle, $ch);
    }
    curl_multi_close($curlHandles->multiHandle);
}
