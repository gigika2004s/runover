import tempfile
import unittest
from pathlib import Path

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.main import WebStaticFiles


class WebCacheHeadersTest(unittest.TestCase):
    """The Flutter web bundle has fixed file names, so a deploy is invisible
    while the browser keeps answering from its cache."""

    def _client(self, directory: str) -> TestClient:
        site = FastAPI()
        site.mount("/", WebStaticFiles(directory=directory, html=True), name="web")
        return TestClient(site)

    def test_bundle_is_always_revalidated(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "index.html").write_text("<html>runover</html>", encoding="utf-8")
            Path(tmp, "main.dart.js").write_text("// bundle", encoding="utf-8")
            client = self._client(tmp)

            for path in ("/", "/main.dart.js"):
                response = client.get(path)
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.headers["cache-control"], "no-cache")

                etag = response.headers["etag"]
                again = client.get(path, headers={"if-none-match": etag})
                self.assertEqual(again.status_code, 304)
                self.assertEqual(again.headers["cache-control"], "no-cache")

    def test_a_changed_bundle_is_not_answered_with_304(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp, "main.dart.js")
            bundle.write_text("// old", encoding="utf-8")
            client = self._client(tmp)

            stale_etag = client.get("/main.dart.js").headers["etag"]
            bundle.write_text("// new build", encoding="utf-8")
            fresh = client.get("/main.dart.js", headers={"if-none-match": stale_etag})

            self.assertEqual(fresh.status_code, 200)
            self.assertEqual(fresh.text, "// new build")


if __name__ == "__main__":
    unittest.main()
