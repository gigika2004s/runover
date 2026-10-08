import os
import tempfile
import unittest

_tmp = tempfile.TemporaryDirectory()
os.environ['DATABASE_URL'] = 'sqlite:///' + _tmp.name + '/test.db'
os.environ['SECRET_KEY'] = 'local-test-signing-key-for-runover-tests'

from fastapi.testclient import TestClient
from app.core.database import Base, engine, initialize_database
from app.main import app


class LegalPagesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Base.metadata.drop_all(engine)
        initialize_database()
        cls.client = TestClient(app)
        cls.client.__enter__()

    @classmethod
    def tearDownClass(cls):
        cls.client.__exit__(None, None, None)

    def test_privacy_page_is_public(self):
        response = self.client.get('/privacidade')
        self.assertEqual(response.status_code, 200)
        self.assertIn('text/html', response.headers['content-type'])
        for needle in ('LGPD', 'Cookies', 'Exclu', 'Reten'):
            self.assertIn(needle, response.text)


if __name__ == '__main__':
    unittest.main()
