import React, {useEffect, useMemo, useState} from 'react';
import {AppBar, Box, Container, Paper, Tab, Tabs, Toolbar, Typography} from '@mui/material';
import LockIcon from '@mui/icons-material/Lock';
import LockOpenIcon from '@mui/icons-material/LockOpen';
import IconButton from '@mui/material/IconButton';
import DescriptionIcon from "@mui/icons-material/Description";
import FolderIcon from '@mui/icons-material/Folder';
import Brightness4Icon from '@mui/icons-material/Brightness4';
import Brightness7Icon from '@mui/icons-material/Brightness7';
import {AnimatePresence, motion} from 'framer-motion';
import EncryptionComponent from './EncryptionComponent';
import DecryptionComponent from "./DecryptionComponent.tsx";
import EncryptLinkComponent from "./EncryptLinkComponent.tsx";
import ReadmeTab from "./components/ReadmeTab.tsx";
import BrowseTab from "./components/BrowseTab.tsx";

type AppProps = {
    toggleTheme: () => void;
    currentMode: 'light' | 'dark';
};

function App({ toggleTheme, currentMode }: AppProps) {
    const queryParams = useMemo(() => new URLSearchParams(window.location.search), []);
    const initialDecryptionValue = queryParams.get("m");

    const [activeTab, setActiveTab] = useState(() => {
        if (queryParams.has("encrypt-link")) {
            return 3; // Encrypt-Link = Tab 3 (verschoben wegen Browse-Tab)
        }
        if (initialDecryptionValue) return 2;               // Decrypt = Tab 2 (verschoben)
        return 0;                                     // Browse = Tab 0 (neuer Standard)
    });

    const [selectedFile, setSelectedFile] = useState<string | null>(null);
    const [fetchedIpAddress, setFetchedIpAddress] = useState<string | null>(null);

    const handleTabChange = (_event: React.SyntheticEvent, newValue: number) => {
        setActiveTab(newValue);
    };

    const handleFileSelect = (filePath: string) => {
        setSelectedFile(filePath);
        console.log('Selected file:', selectedFile);

        // Neuen Browser-Tab mit der Datei öffnen
        const { protocol, hostname, port } = window.location;
        const baseUrl = `${protocol}//${hostname}${port ? `:${port}` : ''}`;
        const fileUrl = `${baseUrl}${filePath}`;

        window.open(fileUrl, '_blank');
    };

    // IP-Adresse beim App-Start abrufen
    const fetchIpAddress = async (): Promise<void> => {
        try {
            const response = await fetch('/func/remote-ip');
            if (!response.ok) {
                throw new Error(`Fehler beim Abrufen der IP-Adresse: ${response.status} ${response.statusText}`);
            }

            const data = await response.text();
            setFetchedIpAddress(data);
        } catch (err) {
            console.error('Error fetching IP address:', err);
        }
    };


    useEffect(() => {
        document.title = 'http-over-all';

        void fetchIpAddress();
    }, []);

    return (
        <Box sx={{ flexGrow: 1 }}>
            <AppBar position="static">
                <Toolbar>
                    <Typography
                        variant="h6"
                        component="div"
                        sx={{ flexGrow: 1, cursor: 'pointer' }}
                        onClick={() => {
                            const { protocol, hostname, port } = window.location;
                            window.location.href = `${protocol}//${hostname}${port ? `:${port}` : ''}/`;
                        }}
                    >
                        http-over-all
                    </Typography>

                    {/* Theme Toggle Button */}
                    <IconButton color="inherit" onClick={toggleTheme}>
                        {currentMode === 'dark' ? <Brightness7Icon /> : <Brightness4Icon />}
                    </IconButton>

                    <Tabs
                        value={activeTab}
                        onChange={handleTabChange}
                        textColor="inherit"
                        indicatorColor="secondary"
                    >
                        <Tab icon={<FolderIcon />} label="Browse" />
                        <Tab icon={<LockIcon />} label="Encrypt" />
                        <Tab icon={<LockOpenIcon />} label="Decrypt" />
                        <Tab icon={<LockIcon />} label="Encrypt-Link" />
                        <Tab icon={<DescriptionIcon />}  label="README" />
                    </Tabs>
                </Toolbar>
            </AppBar>

            <Container maxWidth="md" sx={{ mt: 4 }}>
                <Paper elevation={3} sx={{ p: 2 }}>
                    <AnimatePresence mode="wait">
                        <motion.div
                            key={activeTab}
                            initial={{ opacity: 0, x: activeTab === 0 ? -30 : 30 }}
                            animate={{ opacity: 1, x: 0 }}
                            exit={{ opacity: 0, x: activeTab === 0 ? 30 : -30 }}
                            transition={{ duration: 0.3 }}
                        >
                            {activeTab === 0 && <BrowseTab onFileSelect={handleFileSelect} />}
                            {activeTab === 1 && <EncryptionComponent fetchedIpAddress={fetchedIpAddress}/>}
                            {activeTab === 2 && <DecryptionComponent initialEncryptedValue={initialDecryptionValue} />}
                            {activeTab === 3 && <EncryptLinkComponent queryParams={queryParams} />}
                            {activeTab === 4 && <ReadmeTab />}
                        </motion.div>
                    </AnimatePresence>
                </Paper>
            </Container>
        </Box>
    );
}

export default App;