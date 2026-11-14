"""Direct JSON-RPC to the existing Codex daemon over its Unix WebSocket.

Never enqueue: busy/unloaded threads stay in our cancellable outbox. A racing
turn/start steers an active turn (Codex protocol), rather than creating queued
user input. No thread resume or session configuration overrides are sent.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import socket
import struct
import time


class RPCError(Exception):
    pass


class Client:
    def __init__(self, path=None):
        root = Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex')))
        self.path = path or root / 'app-server-control/app-server-control.sock'
        self.sock = None
        self.sequence = 0

    def __enter__(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(10)
        try:
            self.sock.connect(str(self.path))
            key = base64.b64encode(os.urandom(16)).decode()
            self.sock.sendall((f'GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\n'
                               f'Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n'
                               'Sec-WebSocket-Version: 13\r\n\r\n').encode())
            header = b''
            while not header.endswith(b'\r\n\r\n'):
                header += self.take(1)
                if len(header) > 16384:
                    raise RPCError('Oversized WebSocket handshake')
            lines = header.decode('ascii').split('\r\n')
            fields = {name.lower(): value for name, value in (line.split(': ', 1) for line in lines[1:] if ': ' in line)}
            accept = base64.b64encode(hashlib.sha1((key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
            if not lines[0].startswith('HTTP/1.1 101 ') or fields.get('sec-websocket-accept') != accept:
                raise RPCError('Invalid WebSocket handshake')
            self.call('initialize', {'clientInfo': {'name': 'ytstack-pr-watch', 'version': '0.1.0'},
                                     'capabilities': {'experimentalApi': True}})
            self.send({'method': 'initialized'})
            return self
        except Exception:
            self.sock.close()
            raise

    def __exit__(self, *args):
        self.sock.close()

    def take(self, count):
        result = bytearray()
        while len(result) < count:
            chunk = self.sock.recv(count-len(result))
            if not chunk:
                raise ConnectionError('Codex socket closed')
            result.extend(chunk)
        return bytes(result)

    def frame(self, payload, opcode=1):
        mask = os.urandom(4)
        size = len(payload)
        length = bytes([size]) if size < 126 else (b'\x7e' + struct.pack('!H', size) if size < 65536 else b'\x7f' + struct.pack('!Q', size))
        header = bytes([0x80 | opcode, length[0] | 0x80]) + length[1:]
        self.sock.sendall(header + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))

    def send(self, value):
        self.frame(json.dumps(value).encode())

    def receive(self, deadline):
        parts = bytearray()
        started = False
        while True:
            self.sock.settimeout(max(0.001, deadline-time.monotonic()))
            if time.monotonic() >= deadline:
                raise TimeoutError('Codex RPC timed out')
            first, second = self.take(2)
            opcode, size = first & 15, second & 127
            if first & 0x70 or second & 0x80:
                raise RPCError('Unsupported WebSocket frame')
            if size == 126:
                size = struct.unpack('!H', self.take(2))[0]
            elif size == 127:
                size = struct.unpack('!Q', self.take(8))[0]
            if size + len(parts) > 32*1024*1024:
                raise RPCError('Oversized Codex response')
            data = self.take(size)
            if opcode == 8:
                raise ConnectionError('Codex closed WebSocket')
            if opcode == 9:
                self.frame(data, 10)
                continue
            if opcode == 10:
                continue
            if opcode not in (0, 1) or (opcode == 0) != started:
                raise RPCError('Invalid WebSocket fragmentation')
            started = True
            parts.extend(data)
            if first & 0x80:
                return json.loads(parts)

    def call(self, method, params):
        self.sequence += 1
        request_id = self.sequence
        self.send({'id': request_id, 'method': method, 'params': params})
        deadline = time.monotonic() + 10
        while True:
            message = self.receive(deadline)
            if message.get('id') != request_id:
                # No subscriptions or tools are requested by this client.
                if 'id' in message and 'method' in message:
                    self.send({'id': message['id'], 'error': {'code': -32601, 'message': 'Unsupported client request'}})
                continue
            if 'error' in message:
                raise RPCError('Codex RPC rejected: ' + str(message['error'].get('code')))
            return message['result']

    def status(self, session):
        return self.call('thread/read', {'threadId': session, 'includeTurns': False})['thread']['status']['type']

    def start(self, session, message, dispatch_id):
        result = self.call('turn/start', {'threadId': session,
                           'input': [{'type': 'text', 'text': message}],
                           'clientUserMessageId': dispatch_id})
        return result['turn']['id']
