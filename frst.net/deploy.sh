#!/bin/sh

# Deployment script for FRST.net Aether Test Network BBS
# This script prepares the files for deployment to the web server

echo "FRST.net Aether Test Network - Deployment Script"
echo "================================================"

# Configuration
WEB_ROOT="/var/www/htdocs/aether.frstcomputer.net"
EMSCRIPTEN_BUILD="../build-emscripten"  # Adjust if your build is elsewhere

# Check if running as root or with doas
if [ "$USER" != "root" ]; then
    echo "Note: You may need to run this script with doas for web server deployment"
    echo "For testing, files will be prepared in the current directory"
    WEB_ROOT="./aether-deploy"
    mkdir -p "$WEB_ROOT"
fi

echo ""
echo "Deployment target: $WEB_ROOT"
echo ""

# Create deployment directory structure
echo "1. Creating directory structure..."
mkdir -p "$WEB_ROOT/roms"

# Copy HTML template
echo "2. Copying HTML template..."
cp index.html "$WEB_ROOT/index.html"

# Copy ROM file if it exists
echo "3. Copying ROM file..."
if [ -f "frst_net.exe" ]; then
    cp frst_net.exe "$WEB_ROOT/roms/aether_bbs.rom"
    echo "   ROM copied as aether_bbs.rom"
else
    echo "   Warning: ROM file not found"
fi

# Check for emscripten build files
echo "4. Looking for Emscripten build files..."
if [ -d "$EMSCRIPTEN_BUILD" ]; then
    echo "   Copying from $EMSCRIPTEN_BUILD"
    cp $EMSCRIPTEN_BUILD/pcd68.js "$WEB_ROOT/" 2>/dev/null
    cp $EMSCRIPTEN_BUILD/pcd68.wasm "$WEB_ROOT/" 2>/dev/null
    cp $EMSCRIPTEN_BUILD/pcd68.data "$WEB_ROOT/" 2>/dev/null
else
    echo "   Emscripten build directory not found"
    echo "   You'll need to:"
    echo "   1. Build the emscripten version of pcd68"
    echo "   2. Copy pcd68.js, pcd68.wasm, and pcd68.data to $WEB_ROOT"
fi

# Create a README for the deployment
echo "5. Creating deployment README..."
cat > "$WEB_ROOT/README.txt" << 'EOF'
FRST.net Aether Test Network BBS
=================================

This directory contains the web deployment of the Aether Test Network BBS.

Files needed for deployment:
- index.html     : The main HTML interface
- pcd68.js       : Emscripten JavaScript runtime
- pcd68.wasm     : WebAssembly binary
- pcd68.data     : ROM and data files
- roms/          : ROM files directory

Nginx configuration:
- See nginx-aether.conf for server configuration
- Ensure WASM MIME type is set correctly
- Check logs at /var/www/logs/aether_*.log

To complete deployment:
1. Build emscripten version if not done
2. Copy all files to /var/www/htdocs/aether.frstcomputer.net/
3. Update nginx configuration
4. Reload nginx: doas rcctl reload nginx

EOF

echo ""
echo "Deployment preparation complete!"
echo ""
echo "Files prepared in: $WEB_ROOT"
echo ""
echo "Next steps:"
echo "1. Build the emscripten version of pcd68 if not already done"
echo "2. Copy the deployment files to the web server"
echo "3. Update nginx configuration with nginx-aether.conf"
echo "4. Reload nginx configuration"
echo ""
echo "For testing locally, you can use:"
echo "  cd $WEB_ROOT && python3 -m http.server 8080"
echo "Then visit: http://localhost:8080"