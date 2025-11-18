import { useEffect, useRef, useState } from 'react';
import {
    Box,
    Button,
    Divider,
    IconButton,
    Snackbar,
    Stack,
    TextField,
    ToggleButton,
    ToggleButtonGroup,
    Typography,
    useTheme
} from '@mui/material';
import ContentCopyIcon from '@mui/icons-material/ContentCopy';
import LockIcon from '@mui/icons-material/Lock';
import LockOpenIcon from '@mui/icons-material/LockOpen';
import { usePersistentState } from '../usePersistentState.ts';
import { useClipboardAvailable } from '../useClipboardAvailable.ts';
import { deobfuscate, obfuscate } from '../utils/crypto';

export default function ObfuscationComponent() {
    // Separate state for each mode
    const [obfuscateInput, setObfuscateInput] = usePersistentState('obfuscation_plainText', '');
    const [obfuscateOutput, setObfuscateOutput] = usePersistentState('obfuscation_obfuscatedText', '');
    const [deobfuscateInput, setDeobfuscateInput] = usePersistentState('deobfuscation_obfuscatedText', '');
    const [deobfuscateOutput, setDeobfuscateOutput] = usePersistentState('deobfuscation_plainText', '');

    const [mode, setMode] = usePersistentState<'obfuscate' | 'deobfuscate'>('obfuscationMode', 'obfuscate');
    const [error, setError] = useState<string | null>(null);
    const [snackbarOpen, setSnackbarOpen] = useState(false);
    const [snackbarMessage, setSnackbarMessage] = useState('');

    const inputRef = useRef<HTMLInputElement>(null);
    const outputRef = useRef<HTMLDivElement>(null);

    const theme = useTheme();
    const clipboardAvailable = useClipboardAvailable();

    // Current input and output based on mode
    const currentInput = mode === 'obfuscate' ? obfuscateInput : deobfuscateInput;
    const currentOutput = mode === 'obfuscate' ? obfuscateOutput : deobfuscateOutput;

    const setCurrentInput = (value: string) => {
        if (mode === 'obfuscate') {
            setObfuscateInput(value);
        } else {
            setDeobfuscateInput(value);
        }
    };

    const setCurrentOutput = (value: string) => {
        if (mode === 'obfuscate') {
            setObfuscateOutput(value);
        } else {
            setDeobfuscateOutput(value);
        }
    };

    useEffect(() => {
        inputRef.current?.focus();
    }, [mode]);

    useEffect(() => {
        if (!clipboardAvailable && currentOutput && outputRef.current) {
            const selection = window.getSelection();
            const range = document.createRange();
            range.selectNodeContents(outputRef.current);
            selection?.removeAllRanges();
            selection?.addRange(range);
        }
    }, [currentOutput, clipboardAvailable]);

    const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const newValue = e.target.value;
        setCurrentInput(newValue);

        // Clear output and error when user types
        if (currentOutput) {
            setCurrentOutput('');
        }
        if (error) {
            setError(null);
        }
    };

    const handleProcess = () => {
        setCurrentOutput('');
        setError(null);

        if (!currentInput?.trim()) {
            setError('Please enter text to process');
            return;
        }

        try {
            if (mode === 'obfuscate') {
                const result = obfuscate(currentInput);
                setCurrentOutput(result);


                // Sync to deobfuscate input
                setDeobfuscateInput(result);

                // ⭐ Clear deobfuscate OUTPUT when obfuscating
                setDeobfuscateOutput('');

            } else {
                const result = deobfuscate(currentInput);
                setCurrentOutput(result);

                // Sync to obfuscate input
                setObfuscateInput(result);

                // ⭐ Clear obfuscate OUTPUT when deobfuscating
                setObfuscateOutput('');
            }
        } catch (err) {
            console.error('Processing error:', err);
            setError(`An error occurred during ${mode === 'obfuscate' ? 'obfuscation' : 'deobfuscation'}: ${err instanceof Error ? err.message : 'Unknown error'}`);
        }
    };

    const handleModeChange = (_event: React.MouseEvent<HTMLElement>, newMode: 'obfuscate' | 'deobfuscate' | null) => {
        if (newMode !== null && newMode !== mode) {
            // When switching modes, try to intelligently swap input/output if available
            if (mode === 'obfuscate' && obfuscateOutput) {
                // Switching to deobfuscate: use obfuscated output as deobfuscate input
                setDeobfuscateInput(obfuscateOutput);
            } else if (mode === 'deobfuscate' && deobfuscateOutput) {
                // Switching to obfuscate: use plain output as obfuscate input
                setObfuscateInput(deobfuscateOutput);
            }

            setMode(newMode);
            setError(null);
        }
    };

    const handleCopy = async () => {
        try {
            await navigator.clipboard.writeText(currentOutput);
            setSnackbarMessage('Copied to clipboard');
            setSnackbarOpen(true);
        } catch (err) {
            console.error('Clipboard copy failed:', err);
        }
    };

    return (
        <Box sx={{ maxWidth: 800, mx: 'auto', p: 3 }}>
            <Typography variant="h5" gutterBottom>
                Text Obfuscation
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                Obfuscate or deobfuscate text using Jetty-compatible obfuscation algorithm.
                Use this to hide sensitive configuration values or passwords in plain text files.
            </Typography>

            <Stack spacing={3}>
                {/* Mode Selector */}
                <Box>
                    <Typography variant="subtitle2" sx={{ mb: 1, fontWeight: 'medium' }}>
                        Select Operation
                    </Typography>
                    <ToggleButtonGroup
                        value={mode}
                        exclusive
                        onChange={handleModeChange}
                        aria-label="obfuscation mode"
                        fullWidth
                        color="primary"
                    >
                        <ToggleButton value="obfuscate" aria-label="obfuscate text">
                            <LockIcon sx={{ mr: 1 }} />
                            Obfuscate
                        </ToggleButton>
                        <ToggleButton value="deobfuscate" aria-label="deobfuscate text">
                            <LockOpenIcon sx={{ mr: 1 }} />
                            Deobfuscate
                        </ToggleButton>
                    </ToggleButtonGroup>
                </Box>

                {/* Input Field */}
                <TextField
                    label={mode === 'obfuscate' ? 'Plain Text' : 'Obfuscated Text (...)'}
                    multiline
                    fullWidth
                    minRows={4}
                    maxRows={8}
                    value={currentInput}
                    onChange={handleInputChange}
                    inputRef={inputRef}
                    error={!currentInput && error !== null}
                    helperText={
                        !currentInput && error !== null
                            ? 'This field is required'
                            : mode === 'deobfuscate'
                                ? 'Enter obfuscated text'
                                : 'Enter the text you want to obfuscate'
                    }
                    sx={{
                        '& .MuiInputBase-input': {
                            fontFamily: 'monospace',
                        },
                    }}
                />

                {/* Process Button */}
                <Button
                    variant="contained"
                    onClick={handleProcess}
                    disabled={!currentInput}
                    size="large"
                    startIcon={mode === 'obfuscate' ? <LockIcon /> : <LockOpenIcon />}
                >
                    {mode === 'obfuscate' ? 'Obfuscate Text' : 'Deobfuscate Text'}
                </Button>

                {/* Error Message */}
                {error && (
                    <Typography color="error" variant="body2">
                        {error}
                    </Typography>
                )}

                {/* Output Section */}
                {currentOutput && (
                    <>
                        <Divider />

                        <Box>
                            <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 1 }}>
                                <Typography variant="subtitle1" fontWeight="bold">
                                    {mode === 'obfuscate' ? 'Obfuscated Result' : 'Deobfuscated Result'}
                                </Typography>

                                {clipboardAvailable && (
                                    <IconButton
                                        onClick={handleCopy}
                                        color="primary"
                                        title="Copy to clipboard"
                                    >
                                        <ContentCopyIcon />
                                    </IconButton>
                                )}
                            </Stack>

                            <Box
                                ref={outputRef}
                                sx={{
                                    p: 2,
                                    backgroundColor: theme.palette.mode === 'dark' ? '#1e1e1e' : '#f5f5f5',
                                    borderRadius: 1,
                                    border: `1px solid ${theme.palette.divider}`,
                                    fontFamily: 'monospace',
                                    fontSize: '0.9rem',
                                    wordBreak: 'break-all',
                                    userSelect: 'text',
                                    minHeight: '60px',
                                }}
                            >
                                {currentOutput}
                            </Box>

                            <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                                {clipboardAvailable
                                    ? 'Click the copy icon to copy the result to clipboard.'
                                    : 'The text has been automatically selected. Press Ctrl+C or Cmd+C to copy.'}
                            </Typography>
                        </Box>
                    </>
                )}
            </Stack>

            <Snackbar
                open={snackbarOpen}
                autoHideDuration={3000}
                onClose={() => setSnackbarOpen(false)}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
                message={snackbarMessage}
                slotProps={{
                    content: {
                        sx: {
                            justifyContent: 'center',
                            textAlign: 'center',
                            backgroundColor: (theme) =>
                                theme.palette.mode === 'dark' ? '#333' : '#1976d2',
                            color: '#fff',
                        },
                    },
                }}
            />
        </Box>
    );
}
