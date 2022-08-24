#!/usr/bin/env python
import os

try:
    from http import server # Python 3
except ImportError:
    import SimpleHTTPServer as server # Python 2

class MyHTTPRequestHandler(server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_my_headers()

        server.SimpleHTTPRequestHandler.end_headers(self)

    def send_my_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")


if __name__ == '__main__':
    web_dir = os.path.join(os.getcwd(), 'zig-out/web/')
    os.chdir(web_dir)

    server.test(HandlerClass=MyHTTPRequestHandler)
