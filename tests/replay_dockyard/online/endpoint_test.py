"""External endpoint inputs cannot introduce plaintext transport or URL secrets."""
import argparse
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('room_runner', Path(__file__).with_name('run.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

class EndpointTests(unittest.TestCase):
    def test_explicit_wss_endpoint_survives_exactly(self):
        value = 'wss://mc.laserturtle.net:62127/replay-room/dockyard'
        self.assertEqual(runner.external_service_url(value), value)

    def test_invalid_and_secret_bearing_urls_are_refused_without_echo(self):
        for value in ['ws://example.com/room', 'https://example.com/room', 'wss:///room',
                      'wss://name:SECRET_VALUE@example.com/room',
                      'wss://example.com/room?token=SECRET_VALUE',
                      'wss://example.com/room#SECRET_VALUE', 'wss://example.com:bad/room']:
            with self.subTest(value=value):
                with self.assertRaises(argparse.ArgumentTypeError) as caught:
                    runner.external_service_url(value)
                self.assertNotIn('SECRET_VALUE', str(caught.exception))

    def test_private_forwarding_is_explicitly_limited_to_literal_loopback(self):
        for value in ['ws://127.0.0.1:49740', 'ws://[::1]:49740']:
            self.assertEqual(runner.loopback_service_url(value), value)
        for value in ['ws://example.com:49740', 'ws://10.0.0.10:49740',
                      'ws://localhost:49740', 'ws://127.0.0.1?token=SECRET_VALUE']:
            with self.assertRaises(argparse.ArgumentTypeError) as caught:
                runner.loopback_service_url(value)
            self.assertNotIn('SECRET_VALUE', str(caught.exception))

if __name__ == '__main__':
    unittest.main()
