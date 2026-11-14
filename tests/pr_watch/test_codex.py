import base64
import hashlib
import json
import socket
import struct
import sys
import tempfile
import threading
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/pr-watch'))
from prwatch.codex import Client


class Transport(unittest.TestCase):
    def test_unix_handshake_masking_fragmentation_ping_and_direct_start(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'daemon.sock'
            server=socket.socket(socket.AF_UNIX);self.addCleanup(server.close);server.bind(str(path));server.listen(1)
            calls=[];errors=[]
            def serve():
                try:
                    conn,_=server.accept();conn.settimeout(5)
                    with conn:
                        def take(n):
                            b=b''
                            while len(b)<n:
                                part=conn.recv(n-len(b))
                                if not part:raise ConnectionError()
                                b+=part
                            return b
                        h=b''
                        while not h.endswith(b'\r\n\r\n'):h+=take(1)
                        key=next(x.split(b': ',1)[1] for x in h.split(b'\r\n') if x.startswith(b'Sec-WebSocket-Key:'))
                        accept=base64.b64encode(hashlib.sha1(key+b'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest())
                        conn.sendall(b'HTTP/1.1 101 Switching Protocols\r\nSec-WebSocket-Accept: '+accept+b'\r\n\r\n')
                        def frame(op,data):
                            conn.sendall(bytes([op,len(data)])+data)
                        while len(calls)<4:
                            first,second=take(2);self.assertTrue(second&128)
                            size=second&127
                            if size==126:size=struct.unpack('!H',take(2))[0]
                            elif size==127:size=struct.unpack('!Q',take(8))[0]
                            mask=take(4);data=bytes(b^mask[i%4] for i,b in enumerate(take(size)))
                            if first&15==10:continue
                            req=json.loads(data);calls.append(req)
                            if req['method']=='initialized':continue
                            result={'initialize':{},'thread/read':{'thread':{'status':{'type':'idle'}}},'turn/start':{'turn':{'id':'turn-1'}}}[req['method']]
                            data=json.dumps({'id':req['id'],'result':result}).encode()
                            frame(0x89,b'ping');frame(0x01,data[:10]);frame(0x80,data[10:])
                        while conn.recv(4096):pass
                except Exception as exc:errors.append(exc)
            t=threading.Thread(target=serve,daemon=True);t.start()
            with Client(path) as client:
                self.assertEqual(client.status('owner'),'idle')
                self.assertEqual(client.start('owner','notice'*100,'receipt'),'turn-1')
            t.join(5);server.close()
            self.assertFalse(t.is_alive());self.assertEqual(errors,[])
            self.assertEqual([c['method'] for c in calls],['initialize','initialized','thread/read','turn/start'])
            self.assertEqual(calls[-1]['params']['threadId'],'owner')
            self.assertEqual(calls[-1]['params']['clientUserMessageId'],'receipt')
