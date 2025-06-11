<?php

# rm /scripts/php/include/Crypto.php ; nano /scripts/php/include/Crypto.php
# use with php interpreter:
# php -r "include 'Crypto.php'; echo UnsafeCrypto::encrypt('lala', true);" ; echo
# php -r "include 'Crypto.php'; echo UnsafeCrypto::decrypt('IsoGWzW7Tem-2j-cVTIIc1BRL1g', true);" ; echo
include_once "globals.php";

class Crypto
{
    # http://micmap.org/php-by-example/de/function/openssl_get_cipher_methods
    const METHOD = 'AES-128-CTR';

    private static function base64_urlencode(string $data)
    {
        return str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($data));
    }

    private static function base64_urldecode(string $data)
    {
        return base64_decode(str_replace(['-', '_'], ['+', '/'], $data), true);
    }

    private static function isZlibCompressed(string $string): bool
    {
        if (strlen($string) < 2) {
            return false;
        }

        // check zlib Header (CMF and FLG Bytes)
        $header = unpack('C2', substr($string, 0, 2));

        // CMF Byte should be 0x78 by zlib 0x78 (120 decimal)
        // FLG Byte 0x01, 0x9C or 0xDA
        return $header[1] == 120 && in_array($header[2], [1, 156, 218]);
    }

    /**
     * Encrypt (but does not authenticate) a message
     *
     * @param string $message - plaintext message
     * @param boolean $encode - set to TRUE to return a base64-encoded
     * @return string (raw binary)
     */
    public static function encrypt(string $message, bool $encode = false): string
    {
        return self::encrypt_ext(KEY, self::METHOD, $message, $encode);
    }

    /**
     * Encrypt (but does not authenticate) a message
     *
     * @param string $passphrase - passphrase
     * @param string $cipher_algo - cipher_algo (http://micmap.org/php-by-example/de/function/openssl_get_cipher_methods)
     * @param string $message - plaintext message
     * @param boolean $encode - set to TRUE to return a base64-encoded string
     * @return string (raw binary)
     */
    public static function encrypt_ext(string $passphrase, string $cipher_algo, string $message, bool $encode = false): string
    {
        # docker run --rm php:8.2.0-cli-alpine php -r '$c="BF-OFB";$nonceSize=openssl_cipher_iv_length($c);$nonce=openssl_random_pseudo_bytes($nonceSize);$ciphertext=openssl_encrypt("123",$c,"ps7UDnEXq1cmrMzCvNYE5okXK6B4HlckOQWFQCbJ/Nk=",OPENSSL_RAW_DATA,$nonce); echo "nonce:".base64_encode($nonce)."\n"; echo "cipher:".base64_encode($ciphertext)."\n"; echo "all: ".base64_encode($nonce . $ciphertext)."\n";'
        # docker run --rm php:8.2.0-cli-alpine php -r 'print_r(openssl_get_cipher_methods());'
        # docker run --rm php:7.4.0-cli-alpine php -r 'echo "L:".openssl_cipher_iv_length("bf-ofb")."\n";'
        # docker run --rm php:cli-alpine php -r 'echo "CRYPT_KEY:".base64_encode(openssl_random_pseudo_bytes(32))."\n";'

        if (strlen($message) > 500) {
            $compressed = gzcompress($message, 9);
            if (strlen($compressed) < strlen($message)) {
                $message = $compressed;
            }
        }

        $iv_length = openssl_cipher_iv_length($cipher_algo);
        $iv = openssl_random_pseudo_bytes($iv_length);
        $ciphertext = openssl_encrypt(
            $message,
            $cipher_algo,
            $passphrase,
            OPENSSL_RAW_DATA,
            $iv);

        // Now let's pack the IV and the ciphertext together
        // Naively, we can just concatenate
        if ($encode) {
            return self::base64_urlencode($iv . $ciphertext);
        }
        return $iv . $ciphertext;
    }

    /**
     * Decrypt (but does not verify) a message
     *
     * @param string $message - ciphertext message
     * @param boolean $encoded - are we expecting an base64-encoded string?
     * @return string
     * @throws Exception
     */
    public static function decrypt(string $message, bool $encoded = false): string
    {
        return self::decrypt_ext(KEY, self::METHOD, $message, $encoded);
    }

    /**
     * Decrypt (but does not verify) a message
     *
     * @param string $passphrase - passphrase
     * @param string $cipher_algo - cipher_algo (http://micmap.org/php-by-example/de/function/openssl_get_cipher_methods)
     * @param string $message - ciphertext message
     * @param boolean $encoded - are we expecting an base64-encoded string?
     * @return string
     * @throws Exception
     */
    public static function decrypt_ext(string $passphrase, string $cipher_algo, string $message, bool $encoded = false): string
    {
        if ($encoded) {
            $message = self::base64_urldecode($message);
            if ($message === false) {
                throw new Exception('Encryption failure');
            }
        }

        $iv_length = openssl_cipher_iv_length($cipher_algo);
        # php -r 'echo "iv: ".mb_substr(base64_decode(str_replace(["-","_"], ["+","/"], "FPkwTGnJ5stmrcHbbj4e6zwoVtuff-wL4g-c0mIN00h6Hgx6nMGko1BwOYP_2JXC"), true), 0, 8, "8bit")."\n";'
        $iv = mb_substr($message, 0, $iv_length, '8bit');
        # php -r 'echo "ciphertext: ".mb_substr(base64_decode(str_replace(["-","_"], ["+","/"], "FPkwTGnJ5stmrcHbbj4e6zwoVtuff-wL4g-c0mIN00h6Hgx6nMGko1BwOYP_2JXC"), true), 8, null, "8bit")."\n";'
        $ciphertext = mb_substr($message, $iv_length, null, '8bit');

        $decrypted =  openssl_decrypt(
            $ciphertext,
            $cipher_algo,
            $passphrase,
            OPENSSL_RAW_DATA,
            $iv
        );

        if (self::isZlibCompressed($decrypted)) {
            $decrypted = gzuncompress($decrypted);
        }
        return $decrypted;
    }
}

