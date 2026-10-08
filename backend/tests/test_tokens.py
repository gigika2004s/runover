import base64
import hashlib
import hmac
import json
import os
import tempfile
import time
import unittest

_tmp = tempfile.TemporaryDirectory()
os.environ['DATABASE_URL'] = 'sqlite:///' + _tmp.name + '/test.db'
os.environ['SECRET_KEY'] = 'local-test-signing-key-for-runover-tests'

from app.core.tokens import InvalidToken, decode, encode

SECRET = 'test-secret-with-at-least-32-chars!!'


def _compact(header: dict, payload: dict, secret: str = SECRET) -> str:
    def b64(data: bytes) -> str:
        return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

    h = b64(json.dumps(header).encode())
    p = b64(json.dumps(payload).encode())
    s = b64(hmac.new(secret.encode(), f'{h}.{p}'.encode(), hashlib.sha256).digest())
    return f'{h}.{p}.{s}'


class StdlibTokenTests(unittest.TestCase):
    def test_roundtrip(self):
        token = encode({'sub': 'u1', 'exp': int(time.time()) + 60}, SECRET)
        payload = decode(token, SECRET)
        self.assertEqual(payload['sub'], 'u1')

    def test_wrong_secret_rejected(self):
        token = encode({'sub': 'u1', 'exp': int(time.time()) + 60}, SECRET)
        with self.assertRaises(InvalidToken):
            decode(token, 'another-secret-with-32-chars!!!!!')

    def test_tampered_payload_rejected(self):
        token = encode({'sub': 'u1', 'exp': int(time.time()) + 60}, SECRET)
        head, _, sig = token.split('.')
        forged = _compact(
            {'alg': 'HS256', 'typ': 'JWT'},
            {'sub': 'admin', 'exp': int(time.time()) + 60},
        )
        with self.assertRaises(InvalidToken):
            decode(f'{head}.{forged.split(".")[1]}.{sig}', SECRET)

    def test_non_hs256_algorithm_rejected(self):
        token = _compact(
            {'alg': 'RS256', 'typ': 'JWT'},
            {'sub': 'u1', 'exp': int(time.time()) + 60},
        )
        with self.assertRaises(InvalidToken):
            decode(token, SECRET)

    def test_none_algorithm_rejected(self):
        token = _compact(
            {'alg': 'none'},
            {'sub': 'u1', 'exp': int(time.time()) + 60},
        )
        with self.assertRaises(InvalidToken):
            decode(token, SECRET)

    def test_expired_token_rejected(self):
        token = encode({'sub': 'u1', 'exp': int(time.time()) - 1}, SECRET)
        with self.assertRaises(InvalidToken):
            decode(token, SECRET)

    def test_nonfinite_exp_rejected(self):
        with self.assertRaises(ValueError):
            encode({'sub': 'u1', 'exp': float('nan')}, SECRET)
        with self.assertRaises(ValueError):
            encode({'sub': 'u1', 'exp': float('inf')}, SECRET)
        for exp in (float('nan'), float('inf'), float('-inf')):
            token = _compact(
                {'alg': 'HS256', 'typ': 'JWT'},
                {'sub': 'u1', 'exp': exp},
            )
            with self.assertRaises(InvalidToken, msg=repr(exp)):
                decode(token, SECRET)

    def test_missing_exp_rejected(self):
        token = _compact(
            {'alg': 'HS256', 'typ': 'JWT'}, {'sub': 'u1'},
        )
        with self.assertRaises(InvalidToken):
            decode(token, SECRET)

    def test_garbage_rejected(self):
        for bad in ['', 'a.b', 'a.b.c.d', '!!!', 'x' * 9000]:
            with self.assertRaises(InvalidToken, msg=bad[:10]):
                decode(bad, SECRET)


if __name__ == '__main__':
    unittest.main()
