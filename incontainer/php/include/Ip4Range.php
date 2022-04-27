<?php

include_once "Log.php";

# rm -f /scripts/php/include/Ip4Range.php ; nano /scripts/php/include/Ip4Range.php
# rm -f /scripts/php/include/Ip4Range.php ; nano /scripts/php/include/Ip4Range.php ; php /scripts/php/include/Ip4Range.php

/**
 * Ip4Range, holds all ip4ranges and help checking for included ip4 addresses
 */
class Ip4Range
{
    private string $ip4Ranges;

    public function __construct(string $ip4Ranges)
    {
        $this->ip4Ranges = $ip4Ranges;
    }

    /**
     * compare function
     * @param string $a
     * @param string $b
     * @return int
     */
    private static function cmp_obj(string $a, string $b): int
    {
        if (strpos($a, "!") === 0) {
            return -1;
        }

        if (strpos($b, "!") === 0) {
            return 1;
        }

        if (strpos($a, "-") !== false) {
            return 1;
        }

        if (strpos($b, "-") !== false) {
            return -1;
        }

        return ip2long($a) < ip2long($b) ? -1 : 1;
    }

    /**
     * check whether the given ip4 address is included in the ip4ranges or not
     * @param string $ip
     * @return bool
     */
    public function isIncluded(string $ip): bool
    {
        $ipVal = ip2long($ip);
        if ($ipVal === false) {
            return false;
        }
        $parts = explode(",", $this->ip4Ranges);
        usort($parts, [Ip4Range::class, "cmp_obj"]);
        # $debug = var_export($parts, true);
        # LOG::write(get_called_class(),"parts: $debug");
        foreach ($parts as $part) {
            if (strpos($part, "!") === 0) {
                // ! / handle excluded
                if (ip2long(substr($part, 1)) === $ipVal) {
                    return false;
                }
            } else if (($sep = strpos($part, "-")) === false) {
                // handle single ip address
                if (ip2long($part) === $ipVal) {
                    return true;
                }
            } else {
                // handle range (-)
                $low_ip = ip2long(substr($part, 0, $sep));
                $high_ip = ip2long(substr($part, $sep + 1));

                if ($ipVal <= $high_ip && $low_ip <= $ipVal) {
                    return true;
                }
            }
        }
        return false;
    }
}
/*
$e = new Ip4Range("10.20.1.10-10.20.2.114,10.20.1.15,!10.20.1.14");
echo "10.20.1.15: ".$e->isIncluded("10.20.1.15")."\n";
echo "10.20.1.14: ".$e->isIncluded("10.20.1.14")."\n";
echo "10.20.1.115: ".$e->isIncluded("10.20.1.115")."\n";
echo "10.20.2.115: ".$e->isIncluded("10.20.2.115")."\n";
*/
