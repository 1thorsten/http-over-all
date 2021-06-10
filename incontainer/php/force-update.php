<?php

# rm -f /scripts/php/force-update.php ; nano /scripts/php/force-update.php
include_once "Log.php";
include "common_functions.php";

# http://localhost:8338/php/force-update.php
# http://localhost:8338/force-update/
# http://10.10.0.141:8338/force-update
# http://10.20.1.122:8338/force-update

$time_start = microtime(true);
$remote_addr = $_REQUEST['remote_addr'] ?? $_SERVER['REMOTE_ADDR'];

$callForceUpdate = true;
$cmdOutput = "";
if (file_exists("/var/run/force-update.last")) {
    $file_mtime = filemtime("/var/run/force-update.last");
    list($usec, $sec) = explode(" ", microtime());
    if ($sec - $file_mtime < 11) {
        $cmdOutput = "avoid calling force-update (previous call was ".($sec - $file_mtime)." second(s) ago)";
        LOG::write("force-update.php", $cmdOutput);
        $callForceUpdate = false;
    }
}
if ($callForceUpdate) {
    $cmdOutput = shell_exec('sudo /scripts/force-update.sh');
}

if (accessFromBrowser()) {
    echo "<pre>$cmdOutput</pre>";
} else {
    echo $cmdOutput;
}

$debugOut = '';
if (isset($_SERVER['HTTP_X_DEBUG_OUT'])) {
    $debugOut = "| Debug: {$_SERVER['HTTP_X_DEBUG_OUT']}";
}

LOG::writeTime("force-update.php", $remote_addr, "call force-update.sh {$debugOut}", $time_start);
