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
import {useClipboardAvailable} from './useClipboardAvailable.ts';
import {usePersistentState} from "./usePersistentState.ts";

interface EncryptLinkComponentProps {
    queryParams?: URLSearchParams;
}

export default function EncryptLinkComponent({queryParams: initialParams = undefined}: EncryptLinkComponentProps) {
    const [urlSearchParams, setUrlSearchParams] = usePersistentState('urlSearchParams', initialParams);
    const [linkToEncrypt, setLinkToEncrypt] = usePersistentState('linkToEncrypt', '');
    const [encryptedUrl, setEncryptedUrl] = usePersistentState('encryptedUrl', '');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [snackbarOpen, setSnackbarOpen] = useState(false);
    const [snackbarMessage, setSnackbarMessage] = useState('');
    const [fontSize, setFontSize] = useState('1rem');

    const uriInputRef = useRef<HTMLInputElement>(null);
    const resultRef = useRef<HTMLDivElement | null>(null);

    const theme = useTheme();
    const clipboardAvailable = useClipboardAvailable();
    const {protocol, hostname, port} = window.location;

    useEffect(() => {
        uriInputRef.current?.focus();
    }, []);

    useEffect(() => {
        const length = linkToEncrypt.length;
        if (length > 100) setFontSize('0.7rem');
        else if (length > 60) setFontSize('0.8rem');
        else if (length > 30) setFontSize('0.9rem');
        else setFontSize('1rem');
    }, [linkToEncrypt]);

    useEffect(() => {
        if (!clipboardAvailable && encryptedUrl && resultRef.current) {
            const selection = window.getSelection();
            const range = document.createRange();
            range.selectNodeContents(resultRef.current);
            selection?.removeAllRanges();
            selection?.addRange(range);
        }
    }, [encryptedUrl, clipboardAvailable]);

    useEffect(() => {
        if (urlSearchParams && urlSearchParams.has("encrypt-link")) {
            const uri = urlSearchParams.get("uri");
            const cache = urlSearchParams.get("cache");
            setLinkToEncrypt(uri!);
            handleEncrypt(uri!, cache === "true").then();
        }
    }, [urlSearchParams]);

    const handleEncrypt = async (overrideUri?: string, cache = false) => {
        setEncryptedUrl('');
        setError(null);

        const uri = overrideUri ?? linkToEncrypt;

        if (!uri?.trim()) {
            setError('Please enter a URI');
            return;
        }

        setLoading(true);
        try {
            let pathname = uri;
            try {
                const url = new URL(uri);
                pathname = url.pathname;
                setLinkToEncrypt(pathname)
            } catch (e) {
                // ignore
            }

            const response = await fetch(
                `/func/encrypt-link?uri=${pathname}&scheme=${protocol}&http_host=${hostname}${port ? `:${port}` : ''}&cache=${cache}`,
                {
                    headers: {
                        'Accept': 'application/json'
                    }
                }
            );

            if (!response.ok) {
                throw new Error(`Fehler beim Verschlüsseln des Links: ${response.status} ${response.statusText}`);
            }

            const data = await response.json();

            if (data?.url) {
                const path = `${data.path}/${data.cipher}/${data.resourceName}`;
                setEncryptedUrl(path);
            } else {
                throw new Error('Response does not contain a url field.');
            }

        } catch (err) {
            console.error('Encryption error:', err);
            setError('Encryption failed.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <Box sx={{p: 4}}>
            <Typography variant="h5" gutterBottom>
                Link Encryption
            </Typography>
            <Typography variant="subtitle1" sx={{ mb: 2, color: 'text.secondary' }}>
                Link encryption should be accessed directly via the <strong>http-over-all</strong> service.
                Appending <code>?share</code> to a URL triggers this feature.<br /><br />
                Example:<br />
                <code>{window.location.origin}/resource/file.txt?share</code> → <code>/resource/file.txt</code><br />
            </Typography>
            <TextField
                label="Link to Encrypt (e.g. /resource/file.txt)"
                fullWidth
                margin="normal"
                value={linkToEncrypt}
                disabled={urlSearchParams?.has("encrypt-link")}
                onChange={(e) => {
                    setLinkToEncrypt(e.target.value);
                    if (urlSearchParams) {
                        setUrlSearchParams(undefined);
                    }
                }}
                inputRef={uriInputRef}
                error={!linkToEncrypt && error !== null}
                helperText={!linkToEncrypt && error !== null ? 'This field is required' : ''}
                sx={{
                    '& .MuiInputBase-input': {
                        fontFamily: 'monospace',
                        fontSize: fontSize,
                    },
                }}
            />

            <Button
                variant="contained"
                color="primary"
                onClick={() => handleEncrypt(undefined, urlSearchParams?.get("cache") === "true")}
                disabled={loading || !linkToEncrypt}
                sx={{mt: 2}}
            >
                {loading ? <CircularProgress size={24}/> : 'encrypt-link'}
            </Button>

            {error && (
                <Typography color="error" sx={{mt: 2}}>
                    {error}
                </Typography>
            )}

            {encryptedUrl && (
                <Box sx={{mt: 4}}>
                    <Box
                        sx={{
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center',
                            flexWrap: 'wrap',
                            mb: -1,
                        }}
                    >
                        <Typography variant="subtitle1" gutterBottom>
                            Link to decrypt
                        </Typography>
                        <Stack direction="row" alignItems="center" spacing={1} sx={{ml: 'auto'}}>
                            {clipboardAvailable && (
                                <IconButton onClick={() => {
                                    navigator.clipboard.writeText(encryptedUrl).then();
                                    setSnackbarMessage('Copied to clipboard');
                                    setSnackbarOpen(true);
                                }} color="primary">
                                    <ContentCopyIcon/>
                                </IconButton>
                            )}
                        </Stack>
                    </Box>
                    <Box sx={{display: 'flex', alignItems: 'center', gap: 1}}>
                        <Box
                            ref={resultRef}
                            sx={{
                                flexGrow: 1,
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
                            <Typography
                                component="a"
                                href={encryptedUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                sx={{
                                    color: theme.palette.text.secondary,
                                    borderBottom: '1px solid currentColor',
                                    textDecoration: 'none',
                                    fontFamily: 'monospace',
                                    fontSize: '0.85rem',  // etwas kleinere Schrift
                                    lineHeight: 1.2,           // Kompaktere Zeilenhöhe
                                    paddingBottom: '1px',      // Optional: etwas Platz unterm Text
                                    display: 'inline-block',   // wichtig für Padding + Border-Kontrolle
                                    whiteSpace: 'nowrap',  // Verhindert den Zeilenumbruch
                                    overflow: 'hidden',    // Verhindert das Überlaufen des Textes
                                    textOverflow: 'ellipsis', // Fügt "..." hinzu, wenn der Text zu lang ist
                                    maxWidth: '100%',       // Maximale Breite des Containers
                                    wordBreak: 'break-all', // Verhindert unerwünschte Umbrüche bei langen Wörtern
                                }}
                            >
                                {protocol}//{hostname}{port ? `:${port}` : ''}{encryptedUrl}
                            </Typography>
                        </Box>
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
                anchorOrigin={{vertical: 'bottom', horizontal: 'center'}}
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
