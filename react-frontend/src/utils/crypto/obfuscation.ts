/**
 * deobfuscate text (analog org.eclipse.jetty.util.security.Password#deobfuscate)
 * @param {string} obfuscated
 * @return {String}
 */
export function deobfuscate(obfuscated: string): string {
    if (obfuscated.startsWith("OBF:")) {
        obfuscated = obfuscated.substring(4);
    }

    let b = new Uint8Array(obfuscated.length / 2);
    let len = 0;

    for (let i = 0; i < obfuscated.length; i += 4) {
        let x: string;
        /** @type {number} */
        let i0: number;
        if (obfuscated.charAt(i) === 'U'.charAt(0)) {
            ++i;
            x = obfuscated.substring(i, i + 4);
            i0 = parseInt(x, 36);
            b[len++] = i0 >> 8;
        } else {
            x = obfuscated.substring(i, i + 4);
            i0 = parseInt(x, 36);
            const i1 = i0 / 256;
            const i2 = i0 % 256;
            b[len++] = (i1 + i2 - 254) / 2;
        }
    }
    return new TextDecoder('utf-8').decode(b.slice(0, len));
}

/**
 * obfuscate text (for use within jetty)
 * alternative: java -cp $(locate -r jetty-util-[1-9].*.jar$ | head -1) org.eclipse.jetty.util.security.Password hibernate
 *
 * @param plain
 */
export function obfuscate(plain: string): string {
    let obfuscated = "";

    const b: Uint8Array = new TextEncoder().encode(plain);
    for (let i = 0; i < b.length; ++i) {
        let b1: number = b[i];
        // unsigned to signed
        b1 = b1 << 24 >> 24;
        let b2: number = b[b.length - (i + 1)];
        // unsigned to signed
        b2 = b2 << 24 >> 24;

        let i0: number;
        if (b1 >= 0 && b2 >= 0) {
            i0 = 127 + b1 + b2;
            const i2: number = 127 + b1 - b2;
            i0 = i0 * 256 + i2;
            const x = i0.toString(36).toLocaleLowerCase('en-US');
            obfuscated += "0".repeat(Math.max(0, 3 - x.length)) + x;
        } else {
            i0 = (255 & b1) * 256 + (255 & b2);
            const x = i0.toString(36).toLocaleLowerCase('en-US');
            obfuscated += "U" + "0".repeat(Math.max(0, 4 - x.length)) + x;
        }
    }

    return obfuscated;
}
