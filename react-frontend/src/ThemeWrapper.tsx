// ThemeWrapper.tsx
import React from 'react';
import { ThemeProvider, createTheme, CssBaseline, useMediaQuery } from '@mui/material';
import App from './App';

const ThemeWrapper = () => {
    const systemPrefersDark = useMediaQuery('(prefers-color-scheme: dark)');

    // Beim ersten Laden: Zustand aus localStorage oder System
    const [mode, setMode] = React.useState<'light' | 'dark'>(() => {
        const saved = localStorage.getItem('theme');
        if (saved === 'light' || saved === 'dark') return saved;
        return systemPrefersDark ? 'dark' : 'light';
    });

    // Immer speichern, wenn sich der Modus ändert
    React.useEffect(() => {
        localStorage.setItem('theme', mode);
    }, [mode]);

    const toggleTheme = () => {
        setMode((prev) => (prev === 'light' ? 'dark' : 'light'));
    };

    const theme = React.useMemo(
        () =>
            createTheme({
                palette: {
                    mode,
                    primary: {
                        main: '#1976d2',
                    },
                    secondary: {
                        main: '#dc004e',
                    },
                },
            }),
        [mode]
    );

    return (
        <ThemeProvider theme={theme}>
            <CssBaseline />
            <App toggleTheme={toggleTheme} currentMode={mode} />
        </ThemeProvider>
    );
};

export default ThemeWrapper;
