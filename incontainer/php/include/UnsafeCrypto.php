<?php

# rm /scripts/php/include/UnsafeCrypto.php ; nano /scripts/php/include/UnsafeCrypto.php
# use with php interpreter:
# php -r "include 'UnsafeCrypto.php'; echo UnsafeCrypto::encrypt('lala', true);" ; echo
# php -r "include 'UnsafeCrypto.php'; echo UnsafeCrypto::decrypt('tsdtPHQdtFbxdjCxaP3HclvPLxc', true);" ; echo
include_once "globals.php";
 
class UnsafeCrypto {
    # http://micmap.org/php-by-example/de/function/openssl_get_cipher_methods
    const METHOD = 'AES-128-CTR';

    private static function base64_urlencode($data){
        return str_replace(['+','/','='], ['-','_',''], base64_encode($data));
    }

    private static function base64_urldecode($data){
        return base64_decode(str_replace(['-','_'], ['+','/'], $data), true);
    }
    /**
     * Encrypts (but does not authenticate) a message
     * 
     * @param string $message - plaintext message
     * @param boolean $encode - set to TRUE to return a base64-encoded 
     * @return string (raw binary)
     */
    public static function encrypt(string $message, bool $encode = false): string {
        $nonceSize = openssl_cipher_iv_length(self::METHOD);
        $nonce = openssl_random_pseudo_bytes($nonceSize);

        $ciphertext = openssl_encrypt(
            $message,
            self::METHOD,
            KEY,
            OPENSSL_RAW_DATA,
            $nonce
        );

        // Now let's pack the IV and the ciphertext together
        // Naively, we can just concatenate
        if ($encode) {
            return self::base64_urlencode($nonce.$ciphertext);
        }
        return $nonce.$ciphertext;
    }

    /**
     * Decrypts (but does not verify) a message
     * 
     * @param string $message - ciphertext message
     * @param boolean $encoded - are we expecting an encoded string?
     * @return string
     */
    public static function decrypt($message, $encoded = false) {
        if ($encoded) {
            $message = self::base64_urldecode($message);
            if ($message === false) {
                throw new Exception('Encryption failure');
            }
        }

        $nonceSize = openssl_cipher_iv_length(self::METHOD);
        $nonce = mb_substr($message, 0, $nonceSize, '8bit');
        $ciphertext = mb_substr($message, $nonceSize, null, '8bit');

        $plaintext = openssl_decrypt(
            $ciphertext,
            self::METHOD,
            KEY,
            OPENSSL_RAW_DATA,
            $nonce
        );

        return $plaintext;
    }
}
?>
