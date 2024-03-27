rm -rf softconex/sce-scripts/
mkdir -p softconex/sce-scripts/ ; wget -P softconex/sce-scripts/ -q --no-check-certificate -e robots=off --no-verbose -nc -r -l inf --preserve-permissions -np -X '/*/*/*/airimgupd/,/*/*/*/ibe-scripts/scripts/nagios/,/*/*/*/ibe-scripts/scripts/icinga/,/*/*/*/resource_restrictions/,/*/*/*/sce-data/' -R 'index.html*' -nH --cut-dirs=3 http://localhost:8338/sce-scripts/
