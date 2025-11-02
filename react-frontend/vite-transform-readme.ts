import { Plugin } from 'vite';
import { readFile, writeFile, mkdir } from 'fs/promises';
import path from 'path';

export function transformReadmePlugin(): Plugin {
    return {
        name: 'transform-readme-plugin',
        apply: 'build',
        async buildStart() {
            const sourcePath = path.resolve(__dirname, '../incontainer/README.md');
            const destDir = path.resolve(__dirname, 'public');
            const destPath = path.join(destDir, 'README.md');

            try {
                let content = await readFile(sourcePath, 'utf-8');

                // Regex: Sucht Zeilen mit "# <a name="..."></a> Titel"
                content = content.replace(
                    /^#\s*<a name="[^"]+"><\/a>\s*(.+)$/gm,
                    '## **$1**'
                );

                await mkdir(destDir, { recursive: true });
                await writeFile(destPath, content, 'utf-8');

                console.log('README.md wurde erfolgreich transformiert und kopiert.');
            } catch (err) {
                console.error('Fehler beim Transformieren der README.md:', err);
            }
        },
    };
}
