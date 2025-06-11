import {useEffect, useRef, useState} from 'react';
import {
    Box,
    Button,
    CircularProgress,
    IconButton,
    Snackbar,
    Stack,
    TextField,
    Typography,
    useTheme
} from '@mui/material';
import ContentCopyIcon from '@mui/icons-material/ContentCopy';
import axios from 'axios';
import {useClipboardAvailable} from "./useClipboardAvailable.ts";
import {usePersistentState} from "./usePersistentState.ts";

function DecryptionComponent({initialEncryptedValue = ''}: { initialEncryptedValue?: string | null }) {
    const [encryptedInput, setEncryptedInput] = usePersistentState('encryptedInput', initialEncryptedValue);
    const [decryptedResult, setDecryptedResult] = usePersistentState('decryptedResult', '');
    const [validHeader, setValidHeader] = useState<string | null>(null);
    const [forHostsHeader, setForHostsHeader] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [snackbarOpen, setSnackbarOpen] = useState(false);

    const inputRef = useRef<HTMLInputElement>(null);
    const resultRef = useRef<HTMLInputElement>(null);

    const theme = useTheme();
    const clipboardAvailable = useClipboardAvailable();

    useEffect(() => {
        if (!clipboardAvailable && decryptedResult && resultRef.current) {
            const selection = window.getSelection();
            const range = document.createRange();
            range.selectNodeContents(resultRef.current);
            selection?.removeAllRanges();
            selection?.addRange(range);
        }
    }, [decryptedResult, clipboardAvailable]);

    useEffect(() => {
        if (initialEncryptedValue && inputRef.current) {
            // shrink-Label aktivieren durch Fokuswechsel
            inputRef.current.focus();
            inputRef.current.blur();
            handleDecrypt().then();
        }
    }, [initialEncryptedValue]);

    const handleDecrypt = async () => {
        setDecryptedResult('');
        setValidHeader(null);
        setForHostsHeader(null);
        setError(null);

        if (!encryptedInput) {
            setError('Please enter encrypted text');
            return;
        }

        setLoading(true);

        try {
            const response = await axios.post<string>('/func/decrypt-msg', encryptedInput);
            setDecryptedResult(response.data);

            const valid = response.headers['valid'];
            if (valid) {
                setValidHeader(valid);
            }
            const forHosts = response.headers['for-hosts'];
            if (forHosts) {
                setForHostsHeader(forHosts);
            }

            // Automatically select if no clipboard support
            if (!clipboardAvailable && resultRef.current) {
                resultRef.current.focus();
            }
        } catch (err) {
            console.error('Decryption error:', err);
            setError('An error occurred during decryption. It is possible that you are not allowed to decrypt the text!!');
        } finally {
            setLoading(false);
        }
    };

    const handleCopy = async () => {
        try {
            await navigator.clipboard.writeText(decryptedResult);
            setSnackbarOpen(true);
        } catch (err) {
            console.error('Clipboard copy failed:', err);
        }
    };

    return (
        <Box component="form" sx={{p: 4}}>
            <Typography variant="h4" component="h1" gutterBottom>
                Text Decryption
            </Typography>
            <Typography variant="subtitle1" sx={{ mb: 2, color: 'text.secondary' }}>
                Decrypt text segments that were encrypted using Text Encryption. If decryption fails, it may be due to missing authorization (e.g., IP address not permitted or validity period expired).
            </Typography>
            <TextField
                label="Encrypted Text"
                fullWidth
                required
                multiline
                margin="normal"
                value={encryptedInput}
                disabled={initialEncryptedValue !== null}
                onChange={(e) => setEncryptedInput(e.target.value)}
                inputRef={inputRef}
                error={!encryptedInput && error !== null}
                helperText={!encryptedInput && error !== null ? 'This field is required' : ''}
                autoFocus
                maxRows={5}
                slotProps={{
                    inputLabel: {shrink: true},
                    input: {sx: {fontFamily: 'monospace'}}
                }}
            />

            <Button
                variant="contained"
                color="primary"
                sx={{mt: 2}}
                onClick={handleDecrypt}
                disabled={loading || !encryptedInput}
            >
                {loading ? <CircularProgress size={24}/> : 'Decrypt'}
            </Button>

            {error && (
                <Typography color="error" sx={{mt: 2}}>
                    {error}
                </Typography>
            )}

            {decryptedResult && (
                <Box sx={{mt: 4}}>
                    <Box
                        sx={{
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center',
                            flexWrap: 'wrap',
                            mb: 1,
                        }}
                    >
                        {validHeader && (
                            <Typography variant="caption" sx={{mb: -1, display: 'block', color: 'text.secondary'}}>
                                Valid until: {validHeader}
                            </Typography>
                        )}
                        {forHostsHeader && (
                            <Typography variant="caption" sx={{mb: -1, display: 'block', color: 'text.secondary'}}>
                                Valid for: {forHostsHeader}
                            </Typography>
                        )}
                        <Stack direction="row" alignItems="center" spacing={1} sx={{ml: 'auto'}}>
                            {clipboardAvailable && (
                                <IconButton onClick={handleCopy} color="primary">
                                    <ContentCopyIcon/>
                                </IconButton>
                            )}
                        </Stack>
                    </Box>
                    <Box
                        ref={resultRef}
                        sx={{
                            p: 2,
                            border: '1px solid #ccc',
                            borderRadius: 1,
                            backgroundColor: theme.palette.mode === 'dark' ? '#1e1e1e' : '#f5f5f5',
                            fontFamily: 'monospace',
                            wordBreak: 'break-word',
                            whiteSpace: 'pre-wrap',
                            userSelect: 'text',
                            cursor: 'text',
                            fontSize: '0.85rem',
                            maxHeight: 'calc(100vh - 600px)', // 250px = geschätzter Platz für Header, Margin etc.
                            overflowY: 'auto',
                        }}
                    >
                        {decryptedResult}
                    </Box>

                    <Typography variant="caption" sx={{mt: 1, color: 'text.secondary'}}>
                        {clipboardAvailable
                            ? 'Click the copy icon or select the text manually.'
                            : 'The text has been automatically selected. Press Ctrl+C or Cmd+C to copy.'}
                    </Typography>
                </Box>
            )}

            <Snackbar
                open={snackbarOpen}
                autoHideDuration={3000}
                onClose={() => setSnackbarOpen(false)}
                message="Copied to clipboard"
                anchorOrigin={{vertical: 'bottom', horizontal: 'center'}}
                slotProps={{
                    content: {
                        sx: {
                            justifyContent: 'center',
                            textAlign: 'center',
                            backgroundColor: (theme) => theme.palette.mode === 'dark' ? '#333' : '#1976d2', // Hintergrundfarbe für Dark und Light
                            color: (theme) => theme.palette.mode === 'dark' ? '#fff' : '#fff', // Textfarbe für Dark und Light
                        },
                    },
                }}
            />
        </Box>
    );
}

export default DecryptionComponent;
