import { useEffect, useState } from "react";

export function usePersistentState<T>(key: string, defaultValue: T): [T, (val: T) => void, () => void] {
    const [value, setValue] = useState<T>(() => {
        const stored = sessionStorage.getItem(key);
        return stored ? JSON.parse(stored) : defaultValue;
    });

    useEffect(() => {
        if (value !== defaultValue) {
            if (value === undefined) {
                sessionStorage.removeItem(key);
            } else {
                sessionStorage.setItem(key, JSON.stringify(value));
            }
        } else {
            sessionStorage.removeItem(key);
        }
    }, [key, value, defaultValue]);

    // Funktion zum Entfernen des Wertes aus dem lokalen Speicher
    const removeValue = () => {
        sessionStorage.removeItem(key);
        setValue(defaultValue); // Zustand zurücksetzen auf den Standardwert
    };

    return [value, setValue, removeValue];
}
