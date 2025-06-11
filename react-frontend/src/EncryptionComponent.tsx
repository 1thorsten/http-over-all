import {useEffect, useMemo, useRef, useState} from 'react';
import {
    Box,
    Button,
    CircularProgress,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    Grid,
    IconButton,
    Snackbar,
    Stack,
    TextField,
    Typography,
    useTheme
} from '@mui/material';


import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined';
import ContentCopyIcon from '@mui/icons-material/ContentCopy';
import LinkIcon from '@mui/icons-material/Link';
import CodeIcon from '@mui/icons-material/Code';
import axios from 'axios';
import {useClipboardAvailable} from "./useClipboardAvailable.ts";
import {usePersistentState} from "./usePersistentState.ts";

interface EncryptionComponentProps {
    onEncryptedChange?: (data: { result: string, headers: Record<string, string> }) => void;
    showUrls?: boolean;
}

function EncryptionComponent({onEncryptedChange, showUrls = true}: EncryptionComponentProps) {
    const [textToEncrypt, setTextToEncrypt] = usePersistentState('textToEncrypt', '');
    const [ipAddress, setIpAddress] = usePersistentState('ipAddress', '');
    const [validity, setValidity] = usePersistentState('validity', '');
    const [encryptedResult, setEncryptedResult] = usePersistentState('encryptedResult', '');
    const [loading, setLoading] = useState<boolean>(false);
    const [error, setError] = useState<string | null>(null);
    const [snackbarOpen, setSnackbarOpen] = useState<boolean>(false);
    const [snackbarMessage, setSnackbarMessage] = useState<string>('');
    const [responseHeaders, setResponseHeaders] = useState<Record<string, string>>({});
    const [dialogOpen, setDialogOpen] = useState(false);

    const textFieldRef = useRef<HTMLInputElement>(null);
    const encryptedTextRef = useRef<HTMLDivElement | null>(null);

    const theme = useTheme();
    const clipboardAvailable = useClipboardAvailable();

    useEffect(() => {
        if (!ipAddress) {
            fetchIpAddress().then();
        }

        textFieldRef.current?.focus();
    }, []);

    useEffect(() => {
        if (!clipboardAvailable && encryptedResult && encryptedTextRef.current) {
            const selection = window.getSelection();
            const range = document.createRange();
            range.selectNodeContents(encryptedTextRef.current);
            selection?.removeAllRanges();
            selection?.addRange(range);
        }
    }, [encryptedResult, clipboardAvailable]);

    const usageUrls = useMemo(() => {
        if (!showUrls || !encryptedResult) return [];

        const {protocol, hostname, port} = window.location;
        const base = `${protocol}//${hostname}${port ? `:${port}` : ''}`;
        const uriEncoded = encodeURIComponent(encryptedResult);
        return [
            {
                label: 'API decryption',
                value: `${base}/func/decrypt-msg?m=${uriEncoded}`,
            },
            {
                label: 'Frontend decryption',
                value: `${base}/f/decrypt-msg?m=${uriEncoded}`,
            },
            {
                label: 'cloud_apj.js',
                value: `{ await api.remoteEncrypt('${textToEncrypt}'); await api.remoteDecrypt('${encryptedResult}') }`,
            },
        ];
    }, [encryptedResult, showUrls, textToEncrypt]);

    const fetchIpAddress = async () => {
        try {
            const response = await axios.get('/func/remote-ip');
            setIpAddress(response.data);
        } catch (err) {
            console.error('Error fetching IP address:', err);
            setError('Could not retrieve IP address');
        }
    };

    const handleEncrypt = async () => {
        setEncryptedResult('');
        setResponseHeaders({});
        setError(null);

        if (!textToEncrypt) {
            setError('Please enter text to encrypt');
            return;
        }

        setLoading(true);
        setError(null);

        try {
            let queryParams = '?';
            if (ipAddress) queryParams += 'h=' + ipAddress + '&';
            if (validity) queryParams += 'v=' + validity;

            const response = await axios.post<string>('/func/encrypt-msg' + queryParams, textToEncrypt);
            setEncryptedResult(response.data);

            const headersToExtract = ['for-host', 'for-hosts', 'valid'];
            const filteredHeaders: Record<string, string> = {};
            headersToExtract.forEach((key) => {
                const value = response.headers[key];
                if (value) filteredHeaders[key] = value;
            });
            setResponseHeaders(filteredHeaders);

            if (onEncryptedChange) {
                onEncryptedChange({result: response.data, headers: filteredHeaders});
            }

        } catch (err) {
            console.error('Encryption error:', err);
            setError('An error occurred during encryption');
        } finally {
            setLoading(false);
        }
    };

    return (
        <Box component="form" sx={{p: 4}}>
            <Typography variant="h4" component="h1" gutterBottom>
                Text Encryption
            </Typography>
            <Typography variant="subtitle1" sx={{ mb: 2, color: 'text.secondary' }}>
                Encrypt passwords, text snippets, or code segments. Define decryption access by specifying allowed IP addresses or IP ranges (use * to allow all). Optionally, set a validity period for the encrypted content.
            </Typography>
            <TextField
                label="Text to Encrypt"
                fullWidth
                required
                multiline
                margin="normal"
                value={textToEncrypt}
                onChange={(e) => setTextToEncrypt(e.target.value)}
                error={!textToEncrypt && error !== null}
                helperText={!textToEncrypt && error !== null ? 'This field is required' : ''}
                inputRef={textFieldRef}
                autoFocus
                maxRows={5}
                sx={{
                    '& .MuiInputBase-input': {
                        fontFamily: 'monospace',
                    },
                }}
            />

            <Grid container spacing={2} sx={{mt: 1}}>
                <Grid size={{xs: 12, md: 8}}>
                    <TextField
                        label={`IP Address (e.g. ${ipAddress ?? '192.168.1.5'}, 192.168.2.1-192.168.2.25,!192.168.2.5, *)`}
                        fullWidth
                        margin="normal"
                        value={ipAddress}
                        onChange={(e) => setIpAddress(e.target.value.replace(/\s+/g, ''))}
                        slotProps={{inputLabel: {shrink: true}}}
                        sx={{'& .MuiInputBase-input': {fontFamily: 'monospace'}}}
                    />
                </Grid>

                <Grid size={{xs: 12, md: 4}}>
                    <TextField
                        label="Validity (e.g. now +10 min)"
                        fullWidth
                        margin="normal"
                        value={validity}
                        onChange={(e) => setValidity(e.target.value)}
                        sx={{'& .MuiInputBase-input': {fontFamily: 'monospace'}}}
                    />
                </Grid>
            </Grid>

            <Button
                variant="contained"
                color="primary"
                sx={{mt: 2}}
                onClick={handleEncrypt}
                disabled={loading || !textToEncrypt}
            >
                {loading ? <CircularProgress size={24}/> : 'Encrypt'}
            </Button>

            {error && (
                <Typography color="error" sx={{mt: 2}}>
                    {error}
                </Typography>
            )}

            {encryptedResult && (
                <Box sx={{mt: 4}}>
                    <Box
                        sx={{
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center',
                            flexWrap: 'wrap',
                            mb: 0,
                        }}
                    >
                        <Typography variant="subtitle1">
                            Encrypted Result
                        </Typography>

                        <Stack direction="row" spacing={1}>
                            {Object.keys(responseHeaders).length > 0 && (
                                <IconButton onClick={() => setDialogOpen(true)} color="primary">
                                    <InfoOutlinedIcon/>
                                </IconButton>
                            )}

                            {clipboardAvailable && (
                                <IconButton onClick={() => {
                                    navigator.clipboard.writeText(encryptedResult);
                                    setSnackbarMessage('Copied to clipboard');
                                    setSnackbarOpen(true);
                                }} color="primary">
                                    <ContentCopyIcon/>
                                </IconButton>
                            )}
                        </Stack>
                    </Box>

                    <Box
                        ref={encryptedTextRef}
                        sx={{
                            p: 2,
                            border: `1px solid ${theme.palette.divider}`,
                            borderRadius: 1,
                            backgroundColor: theme.palette.mode === 'dark' ? '#1e1e1e' : '#f5f5f5',
                            color: theme.palette.text.primary,
                            fontFamily: 'monospace',
                            wordBreak: 'break-word',
                            whiteSpace: 'pre-wrap',
                            userSelect: 'text',
                            cursor: 'text',
                            fontSize: '0.85rem',
                            maxHeight: '200px',
                            overflowY: 'auto',
                        }}
                    >
                        {encryptedResult}
                    </Box>


                    <Typography variant="caption" sx={{mt: 1, color: 'text.secondary'}}>
                        {clipboardAvailable
                            ? 'Click the copy icon or select the text manually.'
                            : 'The text has been automatically selected. Press Ctrl+C or Cmd+C to copy.'}
                    </Typography>
                </Box>
            )}

            {usageUrls.length > 0 && (
                <Box sx={{mt: 4}}>
                    <Typography variant="subtitle1" gutterBottom>
                        Usage Snippets
                    </Typography>

                    <Box
                        sx={{
                            p: 2,
                            border: '1px solid',
                            borderColor: 'divider',
                            borderRadius: 2,
                            backgroundColor: 'background.paper',
                            fontFamily: 'monospace',
                        }}
                    >
                        {usageUrls.map(({label, value}, index) => {
                            const isLink = value.startsWith('http');
                            const shortText = (text: string,
                                               length = (isLink ? 50 : 5)) =>
                                text.length > length + 3 ? text.slice(0, length) + '...' : text;

                            const shortValue = (() => {
                                if (!encryptedResult) return value;

                                return value
                                    .replace(encryptedResult, shortText(encryptedResult))
                                    .replace(textToEncrypt, shortText(textToEncrypt));
                            })();

                            return (
                                <Box
                                    key={index}
                                    sx={{
                                        mb: index !== usageUrls.length - 1 ? 2 : 0,
                                        display: 'flex',
                                        alignItems: 'flex-start',
                                        gap: 1,
                                    }}
                                >
                                    <Box sx={{flexGrow: 1}}>
                                        <Typography variant="body2" gutterBottom
                                                    sx={{display: 'flex', alignItems: 'center'}}>
                                            {isLink ? <LinkIcon fontSize="small" sx={{mr: 0.5}}/> :
                                                <CodeIcon fontSize="small" sx={{mr: 0.5}}/>}
                                            {label}:
                                        </Typography>
                                        {isLink ? (
                                            <Typography
                                                component="a"
                                                href={value}
                                                target="_blank"
                                                rel="noopener noreferrer"
                                                sx={{
                                                    display: 'inline-block',
                                                    wordBreak: 'break-all',
                                                    whiteSpace: 'pre-wrap',
                                                    fontFamily: 'monospace',
                                                    color: 'primary.main',
                                                    textDecoration: 'underline',
                                                    '&:hover': {textDecoration: 'none'},
                                                    fontSize: '0.85rem',
                                                    cursor: 'pointer',
                                                }}
                                            >
                                                {(() => {
                                                    try {
                                                        const url = new URL(value);
                                                        const shortened = url.pathname + url.search;
                                                        return shortened.replace(encryptedResult, shortText(encryptedResult));
                                                    } catch {
                                                        return shortValue;
                                                    }
                                                })()}
                                            </Typography>
                                        ) : (
                                            <Typography
                                                sx={{
                                                    fontFamily: 'monospace',
                                                    backgroundColor: theme.palette.mode === 'dark' ? '#2a2a2a' : '#f0f0f0',
                                                    borderRadius: 1,
                                                    p: 1,
                                                    display: 'inline-block',
                                                    fontSize: '0.85rem',
                                                    color: theme.palette.text.primary,
                                                    cursor: 'default',
                                                }}
                                            >
                                                {shortValue}
                                            </Typography>
                                        )}
                                    </Box>

                                    {clipboardAvailable && (
                                        <IconButton
                                            onClick={() => {
                                                navigator.clipboard.writeText(value);
                                                setSnackbarMessage(`Copied ${label}`);
                                                setSnackbarOpen(true);
                                            }}
                                            size="small"
                                            aria-label={`Copy ${label}`}
                                            sx={{mt: 3}}
                                        >
                                            <ContentCopyIcon fontSize="small"/>
                                        </IconButton>
                                    )}
                                </Box>
                            );
                        })}
                    </Box>
                </Box>
            )}


            <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)}>
                <DialogTitle>Server Response Headers</DialogTitle>
                <DialogContent dividers>
                    {Object.entries(responseHeaders).map(([key, value]) => (
                        <Box key={key} sx={{mb: 1}}>
                            <Typography variant="subtitle2" sx={{fontWeight: 'bold'}}>
                                {key}
                            </Typography>
                            <Typography variant="body2" sx={{fontFamily: 'monospace', wordBreak: 'break-word'}}>
                                {value}
                            </Typography>
                        </Box>
                    ))}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDialogOpen(false)}>Close</Button>
                </DialogActions>
            </Dialog>

            <Snackbar
                open={snackbarOpen}
                autoHideDuration={3000}
                onClose={() => setSnackbarOpen(false)}
                anchorOrigin={{vertical: 'bottom', horizontal: 'center'}}
                message={snackbarMessage}
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

export default EncryptionComponent;
