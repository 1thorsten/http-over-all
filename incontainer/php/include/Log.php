<?php 

# rm /scripts/php/include/Log.php ; nano /scripts/php/include/Log.php

function endsWith($string, $endString) { 
    $len = strlen($endString); 
    if ($len == 0) { 
        return true; 
    } 
    return (substr($string, -$len) === $endString); 
} 

Class LOG { 
    const LOG_DIR = '/tmp/php.log';

    public static function writeTime($caller, $host, $msg, $time_start) {
        $executionTime = (microtime(true) - $time_start);
        LOG::writeHost($caller, $host, "$msg (pt: $executionTime s)");
    }

    public static function writeHost($caller, $remote_addr, $msg) {
        if(!endsWith($caller,".php")) {
            $caller = $caller.".php";
        }
        $date = date('Y-m-d H:i:s');
        $entry = "{$remote_addr} - [{$caller}] - [{$date}]: {$msg}\n";
        error_log($entry, 3, self::LOG_DIR); 
    } 

    public static function write($caller, $msg) { 
        if(!endsWith($caller,".php")) {
            $caller = $caller.".php";
        }
        $date = date('Y-m-d H:i:s');
        $entry = "127.0.0.1 - [{$caller}] - [{$date}]: {$msg}\n";
        error_log($entry, 3, self::LOG_DIR); 
    } 
    
}