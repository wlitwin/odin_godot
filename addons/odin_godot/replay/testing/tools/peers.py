"""Bounded local process orchestration for real-peer feature tests.

Owns process groups, logs and a shared deadline. Assertions preserve all logs.
Port reservation is released immediately before launch; caller protocols still
need to detect bind failure (a free-port probe cannot eliminate that race).
"""
from dataclasses import dataclass
from pathlib import Path
import os
import re
import signal
import socket
import subprocess
import time

ERRORS = ('SCRIPT ERROR', 'ERROR:', '_FAIL', 'instances were leaked', 'resources still in use')


@dataclass
class Peer:
    name: str
    command: list[str]
    env: dict[str, str]
    required: tuple[str, ...] = ()


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def run(peers, output: Path, *, timeout=65, stagger=.3, errors=ERRORS, hash_pattern=None):
    output.mkdir(parents=True, exist_ok=True)
    if len({p.name for p in peers}) != len(peers) or not peers:
        raise ValueError('Peers need unique names')
    for peer in peers:
        if not re.fullmatch(r'[a-zA-Z0-9_-]+', peer.name):
            raise ValueError('Invalid peer log name')
    active = []
    deadline = time.monotonic() + timeout
    texts, hashes = {}, {}
    try:
        for peer in peers:
            log = (output / f'{peer.name}.log').open('x')
            try:
                process = subprocess.Popen(peer.command, env=peer.env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            except BaseException:
                log.close()
                raise
            active.append((peer, process, log))
            time.sleep(min(stagger, max(0, deadline-time.monotonic())))
        for peer, process, log in active:
            code = process.wait(timeout=max(.001, deadline-time.monotonic()))
            log.flush()
            text = (output / f'{peer.name}.log').read_text()
            texts[peer.name] = text
            if code or any(marker in text for marker in errors) or any(marker not in text for marker in peer.required):
                raise AssertionError(f'{peer.name} failed; inspect {output / (peer.name + ".log")}')
            if hash_pattern:
                matches = re.findall(hash_pattern, text)
                if len(matches) != 1:
                    raise AssertionError(f'{peer.name}: expected exactly one final hash, got {matches}')
                hashes[peer.name] = matches[0]
        if hashes and len(set(hashes.values())) != 1:
            raise AssertionError(f'Peer hashes differ: {hashes}')
        return {'logs': texts, 'hashes': hashes}
    finally:
        for _, process, log in active:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except (ProcessLookupError, PermissionError):
                if process.poll() is None:process.send_signal(signal.SIGTERM)
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                pass
            # Also reap subprocesses whose parent has already exited.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                if process.poll() is None:process.kill()
            process.wait(timeout=3)
            log.close()
