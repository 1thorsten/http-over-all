<?php 

# rm /scripts/php/include/Log.php ; nano /scripts/php/include/Log.php

function endsWith(string $string, string $endString): bool
{
    $len = strlen($endString); 
    if ($len == 0) { 
        return true; 
    } 
    return (substr($string, -$len) === $endString); 
} 

Class LOG { 
    const LOG_DIR = '/tmp/php.log';

    public static function writeTime(string $caller, string $host, string $msg, float $time_start) {
        $executionTime = (microtime(true) - $time_start);
        LOG::writeHost($caller, $host, "$msg (pt: $executionTime s)");
    }

    public static function writeHost(string $caller, string $remote_addr, string $msg) {
        if(!endsWith($caller,".php")) {
            $caller = $caller.".php";
        }
        $date = date('Y-m-d H:i:s');
        $entry = "{$remote_addr} - [{$caller}] - [{$date}]: {$msg}\n";
        error_log($entry, 3, self::LOG_DIR); 
    } 

    public static function write(string $caller, string $msg) {
        if(!endsWith($caller,".php")) {
            $caller = $caller.".php";
        }
        $date = date('Y-m-d H:i:s');
        $entry = "127.0.0.1 - [{$caller}] - [{$date}]: {$msg}\n";
        error_log($entry, 3, self::LOG_DIR); 
    } 
    
}
