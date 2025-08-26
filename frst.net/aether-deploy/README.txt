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

