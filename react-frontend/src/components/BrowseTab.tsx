import React, {useEffect, useState} from 'react';
import {
    Alert,
    Box,
    Breadcrumbs,
    CircularProgress,
    Link,
    List,
    ListItem,
    ListItemButton,
    Paper,
    Typography
} from '@mui/material';
import {
    Folder as FolderIcon,
    Home as HomeIcon,
    InsertDriveFile as FileIcon,
    NavigateNext as NavigateNextIcon
} from '@mui/icons-material';

interface DirectoryItem {
    name: string;
    encodedName: string;
    type: 'file' | 'directory';
    size?: string;
    lastModified?: string;
}

interface BrowseTabProps {
    onFileSelect?: (filePath: string) => void;
}

const ROOT_PATH = process.env.NODE_ENV === 'production' ? '/' : '/git_timeset/';

const BrowseTab: React.FC<BrowseTabProps> = ({onFileSelect}) => {
        const [currentPath, setCurrentPath] = useState<string>(ROOT_PATH);
        const [items, setItems] = useState<DirectoryItem[]>([]);
        const [loading, setLoading] = useState<boolean>(false);
        const [error, setError] = useState<string | null>(null);

        const formatFileSize = (sizeInBytes: number): string => {
            if (sizeInBytes === 0) return '0 \u00A0\nB';
            const units = ['\u00A0B', 'KB', 'MB', 'GB', 'TB'];
            const unitIndex = Math.floor(Math.log(sizeInBytes) / Math.log(1024));
            const size = sizeInBytes / Math.pow(1024, unitIndex);
            return `${size.toFixed(unitIndex === 0 ? 0 : 1)} ${units[unitIndex]}`;
        };

        const fetchDirectoryContent = async (path: string) => {
            setLoading(true);
            setError(null);

            try {
                const response =  await fetch(path+'?raw=true', {
                    method: 'GET',
                    credentials: 'same-origin'
                });

                // Parse nginx directory listing HTML
                const parser = new DOMParser();
                const doc = parser.parseFromString(await response.text(), 'text/html');
                const rows = doc.querySelectorAll('pre a');

                const parsedItems: DirectoryItem[] = [];

                rows.forEach((link) => {
                    const href = link.getAttribute('href');
                    const text = link.textContent?.trim();

                    if (href && text && href !== '../' && !href.startsWith('http')) {
                        const isDirectory = text.endsWith('/');
                        const name = isDirectory ? text.slice(0, -1) : text;
                        const encodedName = isDirectory ? href.slice(0, -1) : href;
                        if (name) {
                            // Try to extract size and date from nginx listing
                            const parent = link.parentNode;
                            const textContent = parent?.textContent || '';

                            // Extract date and size from nginx directory listing format
                            const matches = textContent.substring(textContent.indexOf(name)).match(/(\d{2}-\w{3}-\d{4} \d{2}:\d{2})\s+(\d+|-)/);

                            parsedItems.push({
                                name,
                                encodedName,
                                type: isDirectory ? 'directory' : 'file',
                                size: matches && matches[2] !== '-' ? matches[2] : undefined,
                                lastModified: matches ? matches[1] : undefined
                            });
                        }
                    }
                });

                setItems(parsedItems);
            } catch (err) {
                setError('Error loading directory');
                console.error('Error fetching directory:', err);
            } finally {
                setLoading(false);
            }
        };

        useEffect(() => {
            fetchDirectoryContent(currentPath);
        }, [currentPath]);

        const handleItemClick = (item: DirectoryItem) => {
            if (item.type === 'directory') {
                const newPath = currentPath === ROOT_PATH
                    ? `${ROOT_PATH}${item.encodedName}/`
                    : `${currentPath}${item.encodedName}/`;
                setCurrentPath(newPath);
            } else {
                const fullPath = currentPath === ROOT_PATH
                    ? `${ROOT_PATH}${item.encodedName}`
                    : `${currentPath}${item.encodedName}`;
                onFileSelect?.(fullPath);
            }
        };

        const handleBreadcrumbClick = (_: string, index: number, arr: {name: string, path: string}[]) => {
            debugger
            if (index === arr.length-1) {
                window.open(currentPath, '_blank');
                return;
            }
            if (index === 0) {
                setCurrentPath(ROOT_PATH);
            } else {
                const pathParts = currentPath.split('/').filter(Boolean);
                let sliceStart = 0;
                if (ROOT_PATH !== '/') {
                    sliceStart = currentPath.startsWith(ROOT_PATH) ? 1 : 0;
                }
                const newPath = ROOT_PATH + pathParts.slice(sliceStart, index).join('/');
                setCurrentPath(newPath.endsWith('/') ? newPath : newPath + '/');
            }
        };

        const getBreadcrumbs = () => {
            if (currentPath === '/') {
                return [{name: 'Root', path: ROOT_PATH}];
            }

            const parts = currentPath.split('/').filter(Boolean);
            const breadcrumbs = [{name: 'Root', path: ROOT_PATH}];

            parts.forEach((part, index) => {
                breadcrumbs.push({
                    name: decodeURIComponent(part),
                    path: ROOT_PATH + parts.slice(0, index + 1).join('/') + '/'
                });
            });

            return breadcrumbs;
        };

        return (
            <Box>
                <Paper elevation={1} sx={{p: 1.5, mb: 2}}>
                    <Breadcrumbs
                        separator={<NavigateNextIcon fontSize="small"/>}
                        aria-label="breadcrumb"
                    >
                        {getBreadcrumbs().map((crumb, index, arr) => (
                            <Link
                                key={index}
                                component="button"
                                variant="body2"
                                onClick={() => handleBreadcrumbClick(crumb.path, index, arr)}
                                sx={{
                                    display: 'flex',
                                    alignItems: 'center',
                                    textDecoration: 'none',
                                    color: 'primary.main',
                                    '&:hover': {
                                        textDecoration: 'underline',
                                    },
                                }}
                            >
                                {index === 0 && <HomeIcon sx={{mr: 0.5, fontSize: 16}}/>}
                                {crumb.name}
                            </Link>
                        ))}
                    </Breadcrumbs>
                </Paper>

                {loading && (
                    <Box display="flex" justifyContent="center" p={4}>
                        <CircularProgress/>
                    </Box>
                )}

                {error && (
                    <Alert severity="error" sx={{mb: 2}}>
                        {error}
                    </Alert>
                )}

                {!loading && !error && (
                    <Paper elevation={1}>
                        <List dense sx={{py: 0}}>
                            {currentPath !== ROOT_PATH && (
                                <ListItem disablePadding>
                                    <ListItemButton
                                        sx={{py: 0.5, display: 'flex'}}
                                        onClick={() => {
                                            let parentPath = currentPath.split('/').slice(0, -2).join('/') + '/';
                                            if (parentPath === '') parentPath = ROOT_PATH;
                                            else if (!parentPath.startsWith(ROOT_PATH)) parentPath = ROOT_PATH + parentPath;
                                            setCurrentPath(parentPath);
                                        }}
                                    >
                                        <Box sx={{display: 'flex', alignItems: 'center', width: '100%'}}>
                                            <Box sx={{width: '24px', minWidth: '24px', mr: 1}}>
                                                <FolderIcon color="action" fontSize="small"/>
                                            </Box>
                                            <Box sx={{width: 'calc(100% - 24px - 120px - 80px - 16px)', minWidth: 0}}>
                                                <Typography
                                                    variant="body2"
                                                    sx={{
                                                        fontFamily: 'monospace',
                                                        overflow: 'hidden',
                                                        textOverflow: 'ellipsis',
                                                        whiteSpace: 'nowrap'
                                                    }}
                                                >
                                                    ../
                                                </Typography>
                                            </Box>
                                            <Box sx={{width: '120px', minWidth: '120px'}}>
                                                <Typography variant="caption" color="text.secondary">
                                                    Parent directory
                                                </Typography>
                                            </Box>
                                            <Box sx={{width: '80px', minWidth: '80px', textAlign: 'right'}}>
                                                {/* Empty space for size column */}
                                            </Box>
                                        </Box>
                                    </ListItemButton>
                                </ListItem>
                            )}

                            {items.map((item, index) => (
                                <ListItem key={index} disablePadding>
                                    <ListItemButton sx={{py: 0.5, display: 'flex'}} onClick={() => handleItemClick(item)}>
                                        <Box sx={{display: 'flex', alignItems: 'center', width: '100%'}}>
                                            <Box sx={{width: '24px', minWidth: '24px', mr: 1}}>
                                                {item.type === 'directory' ? (
                                                    <FolderIcon color="primary" fontSize="small"/>
                                                ) : (
                                                    <FileIcon color="action" fontSize="small"/>
                                                )}
                                            </Box>
                                            <Box sx={{width: 'calc(100% - 24px - 120px - 80px - 16px)', minWidth: 0}}>
                                                <Typography
                                                    variant="body2"
                                                    sx={{
                                                        fontFamily: 'monospace',
                                                        overflow: 'hidden',
                                                        textOverflow: 'ellipsis',
                                                        whiteSpace: 'nowrap'
                                                    }}
                                                >
                                                    {item.name}
                                                </Typography>
                                            </Box>
                                            <Box sx={{width: '130px', minWidth: '130px'}}>
                                                <Typography
                                                    variant="caption"
                                                    color="text.secondary"
                                                    sx={{fontFamily: 'monospace'}}
                                                >
                                                    {item.lastModified}
                                                </Typography>
                                            </Box>
                                            <Box sx={{width: '80px', minWidth: '80px', textAlign: 'right'}}>
                                                <Typography
                                                    variant="caption"
                                                    color="text.secondary"
                                                    sx={{fontFamily: 'monospace'}}
                                                >
                                                    {item.size && item.type === 'file' ? formatFileSize(parseInt(item.size)) : ''}
                                                </Typography>
                                            </Box>
                                        </Box>
                                    </ListItemButton>
                                </ListItem>
                            ))}

                            {items.length === 0 && (
                                <ListItem sx={{py: 2}}>
                                    <Box sx={{width: '100%'}}>
                                        <Typography variant="body2" color="text.secondary">
                                            Empty directory
                                        </Typography>
                                    </Box>
                                </ListItem>
                            )}
                        </List>
                    </Paper>
                )}
            </Box>
        );
    }
;

export default BrowseTab;