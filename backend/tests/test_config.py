import socket
import unittest
from unittest.mock import patch

from app.core.config import pin_ipv4_hostaddr


def _addrinfo(ip):
    return [(socket.AF_INET, socket.SOCK_STREAM, 6, "", (ip, 5432))]


class PinIpv4Tests(unittest.TestCase):
    def test_appends_hostaddr_from_a_record(self):
        url = "postgresql+psycopg://u:p@db.example.com:5432/runover?sslmode=require"
        with patch("socket.getaddrinfo", return_value=_addrinfo("203.0.113.7")):
            pinned = pin_ipv4_hostaddr(url)
        self.assertIn("hostaddr=203.0.113.7", pinned)
        self.assertIn("sslmode=require", pinned)
        self.assertIn("@db.example.com:5432", pinned)

    def test_keeps_existing_hostaddr(self):
        url = "postgresql+psycopg://u:p@db.example.com/runover?hostaddr=198.51.100.9"
        with patch("socket.getaddrinfo", return_value=_addrinfo("203.0.113.7")):
            self.assertIn("hostaddr=198.51.100.9", pin_ipv4_hostaddr(url))

    def test_falls_back_without_a_record(self):
        url = "postgresql+psycopg://u:p@db.example.com/runover"
        with patch("socket.getaddrinfo", side_effect=OSError("dns")):
            self.assertEqual(pin_ipv4_hostaddr(url), url)
        with patch("socket.getaddrinfo", return_value=[]):
            self.assertEqual(pin_ipv4_hostaddr(url), url)

    def test_ignores_urls_without_host(self):
        url = "sqlite:///./runover.db"
        with patch("socket.getaddrinfo") as resolved:
            self.assertEqual(pin_ipv4_hostaddr(url), url)
            resolved.assert_not_called()


if __name__ == "__main__":
    unittest.main()
