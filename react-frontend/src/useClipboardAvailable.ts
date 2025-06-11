import { useEffect, useState } from 'react';

// z.B. aus Umgebungsvariable oder woanders konfiguriert
const allowClipboard = false; // kannst du auch dynamisch aus localStorage, etc. holen

export function useClipboardAvailable(): boolean {
    const [available, setAvailable] = useState(false);

    useEffect(() => {
        const hasClipboard = Boolean(navigator.clipboard && navigator.clipboard.writeText);
        setAvailable(allowClipboard && hasClipboard);
    }, []);

    return available;
}
