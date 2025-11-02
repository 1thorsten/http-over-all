import { useMemo } from 'react';

const allowClipboard = false;

export function useClipboardAvailable(): boolean {
    return useMemo(() => {
        const hasClipboard = Boolean(navigator.clipboard && navigator.clipboard.writeText);
        return allowClipboard && hasClipboard;
    }, []);
}