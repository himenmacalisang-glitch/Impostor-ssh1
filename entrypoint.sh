#!/bin/bash
set -e

ulimit -n 65535 || true

cat /etc/banner.txt

echo "[+] Starting SSH..."
ssh-keygen -A
mkdir -p /run/sshd
/usr/sbin/sshd

echo "[+] Starting UDPGW..."
/usr/local/impostor/bin/udpgw --listen-addr 0.0.0.0:7300 --max-clients 1000 --max-connections-for-client 40 --loglevel warning &

echo "[+] Starting Bridge..."
python3 -c "
import socket, threading

def bridge(a, b):
    try:
        while True:
            d = a.recv(65536)
            if not d: break
            b.sendall(d)
    except: pass
    a.close(); b.close()

def handle(c):
    c.recv(4096)
    c.sendall(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n')
    s = socket.socket()
    s.connect(('127.0.0.1', 22))
    threading.Thread(target=bridge, args=(c,s), daemon=True).start()
    threading.Thread(target=bridge, args=(s,c), daemon=True).start()

srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('127.0.0.1', 2222))
srv.listen(100)
while True:
    c,_ = srv.accept()
    threading.Thread(target=handle, args=(c,), daemon=True).start()
" &

echo "[+] Starting Nginx..."
exec nginx -g "daemon off;"
