"""One-client UDP port forward used only by the native endpoint fixture."""
import json
import selectors
import socket
import threading


class Forward:
    def __init__(self, target_port):
        self.target = ('127.0.0.1', target_port)
        self.front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.back = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.front.bind(('127.0.0.1', 0))
        self.back.bind(('127.0.0.1', 0))
        self.port = self.front.getsockname()[1]
        self.client = None
        self.counts = [0, 0]
        self.stop = threading.Event()
        self.error = None
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()

    def _run(self):
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(self.front, selectors.EVENT_READ, 0)
                selector.register(self.back, selectors.EVENT_READ, 1)
                while not self.stop.is_set():
                    for event, _ in selector.select(.05):
                        data, sender = event.fileobj.recvfrom(65536)
                        if event.data == 0:
                            if self.client is None: self.client = sender
                            if sender != self.client: continue
                            self.back.sendto(data, self.target)
                        else:
                            if sender != self.target or self.client is None: continue
                            self.front.sendto(data, self.client)
                        self.counts[event.data] += 1
        except Exception as error:
            self.error = repr(error)

    def close(self):
        self.stop.set()
        self.thread.join(timeout=2)
        self.front.close()
        self.back.close()
        assert not self.thread.is_alive() and self.error is None, self.error
        return {'advertised_port': self.port, 'listen_port': self.target[1], 'to_listener': self.counts[0], 'to_peer': self.counts[1]}
