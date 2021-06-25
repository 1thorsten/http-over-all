<?php

# rm /scripts/php/include/common_functions.php ; nano /scripts/php/include/common_functions.php

include_once "Log.php";
function denyAccessFromExternal($callingScript) {
    $remoteAddress=$_SERVER['REMOTE_ADDR'];

    if ($remoteAddress != "127.0.0.1") {
        echo "Error: do not call this script directly";
        LOG::write($callingScript,"script was called directly from {$remoteAddress} -> uri: {$_SERVER['REQUEST_URI']}");
        exit;   
    }
}

function accessFromBrowser(): bool
{
    if ($_SERVER['HTTP_ACCEPT'] == "*/*") {
        return false;
    }
    return true;
}

function forwardRequest($url): array
{
    // http://php.net/manual/de/function.parse-url.php
    $parsedUrl = parse_url($url);
    $host = $parsedUrl["host"];
    $path = $parsedUrl["path"];

    $sock = fsockopen($host, 80, $errno, $errstr, 30);
    if (!$sock) die("$errstr ($errno)\n");

    fwrite($sock, "GET {$path} HTTP/1.1\r\n");
    fwrite($sock, "Host: $host\r\n");
    fwrite($sock, "Accept: */*\r\n");
    fwrite($sock, "User-Agent: forwardRequest\r\n");

    // this leads to problems when the client accepts compressed content (gzip, deflate, etc.)
    // with fgets which reads chunks it is only possible to decompress the content in the end
    // but this is problematic when the resource is big
    // it its not real important because it causes only a delay in the communication between SDS and the resource,
    // so it happend only once (proxy cache)
    // the content to the client will be compressed with the help of the underlying nginx
    
    // if(isset($_SERVER['HTTP_ACCEPT_ENCODING'])) {
    //    fwrite($sock, "Accept-Encoding: {$_SERVER['HTTP_ACCEPT_ENCODING']}\r\n");        
    // }

    fwrite($sock, "Connection: Close\r\n");
    fwrite($sock, "\r\n");

    $content_length = null;
    while ($str = trim(fgets($sock, 4096))) {
        // LOG::write("common_functions.php","header -> $str");
        // ensure to return the correct HTTP code (otherwise it returns always HTTP/1.1 200 OK)
        if (strncmp($str, "HTTP/", 5) === 0) {              
            header($str);
            continue;
        }
        $tok = strtok($str, ':');
        if ($tok == 'Content-Type') {
            header($str);
        } else if ($tok == 'Content-Encoding') {
           header($str);
        } else if ($tok == 'Content-Length') {
            $parts = explode(":", $str);
            header($str);
            $content_length = trim($parts[1]);
        } else if ($tok == 'Last-Modified') {
            header($str);
        } else if ($tok == 'ETag') {
            header($str);
        }
    }
    
    // change order of the crypt output (uri ends with filename, so no Content-Dispositon is necessary anymore)
    // $name = basename($url);
    // header("Content-Disposition: inline; filename=\"$name\"");  
    // stream_set_timeout($sock, 600);
    while (!feof($sock)) {
        echo fgets($sock, 4096);
    }
    // $info = stream_get_meta_data($sock);
    fclose($sock);

    // $debug = var_export($info, true);
    // LOG::write("common_functions.php","all bytes sent: $debug");
    return array('Content-Length' => $content_length);
}

# https://prismjs.com/#supported-languages
function determineLanguage($basename): string
{
    $n = strtolower($basename);
    if(strpos($n,".css") !== false) return "lang-css";
    if(strpos($n,"dockerfile") !== false) return "lang-docker";
    if(strpos($n,".go") !== false) return "lang-go";
    if(strpos($n,".groovy") !== false) return "lang-groovy";
    if(strpos($n,".htm") !== false) return "lang-html";
    if(strpos($n,".ini") !== false) return "lang-ini";
    if(strpos($n,".java") !== false) return "lang-java";
    if(strpos($n,".json") !== false) return "lang-json";
    if(strpos($n,".js") !== false) return "lang-javascript";
    if(strpos($n,".lua") !== false) return "lang-lua";
    if(strpos($n,".md") !== false) return "lang-markdown";
    if(strpos($n,".php") !== false) return "lang-php";
    if(strpos($n,".pl") !== false) return "lang-perl";
    if(strpos($n,".pug") !== false) return "lang-pug";
    if(strpos($n,".py") !== false) return "lang-python";
    if(strpos($n,".properties") !== false) return "lang-properties";
    if(strpos($n,".rb") !== false) return "lang-ruby";
    if(strpos($n,".sql") !== false) return "lang-sql";
    if(strpos($n,".sh") !== false) return "lang-bash";
    if(strpos($n,".ts") !== false) return "lang-typescript";
    if(strpos($n,".xml") !== false) return "lang-xml";
    if(strpos($n,".yml") !== false) return "lang-yml";
    if(strpos($n,".yaml") !== false) return "lang-yaml";
    return "lang-markup";
}

