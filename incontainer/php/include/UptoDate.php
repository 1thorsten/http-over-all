<?php
include_once "Log.php";

# rm /scripts/php/include/UptoDate.php ; nano /scripts/php/include/UptoDate.php
# include "UptoDate.php";
# echo UptoDate::cleanUpCache("pom.xml");
# UptoDate::url("/ibe_and_more/java/security/README.txt");
class UptoDate {
    const INTERNAL = "http://127.0.0.1/internal";
    const CACHED_INTERNAL = "http://127.0.0.1/cached_internal";
    const CACHE_PATH = "/nginx-cache/";
    public $path;
    public $lastHttpStatus;
    public $cacheStatus;
    public $cachedFiles;
    public $resourceHeaders;

    public function __construct($path) {
        $this->path = $path;
    }

    public function header($url) {
    #    LOG::write(get_called_class(),"header: $url");
        $h = get_headers($url, 1);

    #    $debug = var_export($h, true);
    #    LOG::write(get_called_class(),"header: $debug");

        if ($h) {
            $this->resourceHeaders = $h;
            if (strstr($h[0], '200') === "200 OK") {
                $array['Last-Modified'] = new \DateTime($h['Last-Modified']);
                if (isset ($h['X-Proxy-Cache'])) {
                    $array['X-Proxy-Cache'] = $h['X-Proxy-Cache'];
                }
                return $array;
            } 
            $this->lastHttpStatus = trim(strstr($h[0], ' '));
        } else {
            LOG::write(get_called_class(),"header: could not get header for $url");
            throw new Exception("header: problem getting header"); 
        }
        return NULL;
    }

    public function url($invalidateCache) {
        if ($this->isCacheInvalid() && $invalidateCache === true) {
            $this->cleanUpCache();
        }

        $baseUrl;
        switch ($this->cacheStatus) {
            case 'CACHE_NO': $baseUrl = self::INTERNAL; break;
            default: $baseUrl = self::CACHED_INTERNAL;
        }
        return $baseUrl.$this->path;
    }

    public function isCacheInvalid() {
        if (!$this->cacheStatus) {
            $this->getCacheStatus($this->path);
        }
        return $this->cacheStatus === "CACHE_OLD";        
    }

    // $path = path from Webserve (/ibe_and_more/java/security/README.txt)
    public function getCacheStatus() {
        if (substr($this->path, -1) === '/') {
            return $this->cacheStatus = "CACHE_NO";
        }
        try {
            $header_cache = $this->header(self::CACHED_INTERNAL.$this->path);
            if ($header_cache === NULL || $header_cache['X-Proxy-Cache'] === "MISS") {      
                return $this->cacheStatus = "CACHE_MISS";
            }
            $header_direct = $this->header(self::INTERNAL.$this->path);

            if ($header_cache['Last-Modified'] == $header_direct['Last-Modified']) {         
                return $this->cacheStatus = "CACHE_HIT";
            }
        } catch(Throwable $t) {
            LOG::write(get_called_class(),"getCacheStatus: declare CACHE_NO -> " . $t->getMessage());
            return $this->cacheStatus = "CACHE_NO";
        }
        LOG::write(get_called_class(),"getCacheStatus: $this->path -> CACHE_OLD");
        return $this->cacheStatus = "CACHE_OLD";
    }

    public function cleanUpCache() {  
        $this->getDirContents(self::CACHE_PATH);
        $len = strlen($this->path);
        
        #$debug = var_export($this->cachedFiles, true);
        #LOG::write(get_called_class(),"cleanUpCache: $debug");

        $found_files = false;
        
        foreach ($this->cachedFiles as $file) {
            if (! file_exists($file) ) {
                LOG::write(get_called_class(),"cleanUpCache: file does not exists -> $file");
                continue;
            }
            $cacheKey = $this->readCacheKeyFromFile($file);

            if(substr($cacheKey, - $len) === $this->path) {
                LOG::write(get_called_class(),"cleanUpCache: delete old cached resource -> $file");
                unlink($file);
                $found_files = true;
            }
        }
        return $found_files;
    }

    public function getDirContents($path) {
        $rii = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($path));

        $files = array(); 
        foreach ($rii as $file) {
            if (!$file->isDir()) {
                $files[] = $file->getPathname();
            }
        }
        return $this->cachedFiles = $files;
    }

    public function readCacheKeyFromFile($filename) {
        $file = new SplFileObject($filename);
        $contents = "";
        $lineNumber = 1;
        do{
            $file->seek($lineNumber++);
            $contents = $file->current();
        } while($file->eof() || !strstr($contents,"KEY:"));
        $contents = substr($contents, 0, -1);
        return $contents;

    }
}

?>