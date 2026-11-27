"""Read a DM-approved URL from the job's .url file and save a standalone PNG in its .txt file."""

import base64
import http.client
import io
import os
import socket
import sys
import threading
from pathlib import Path
from urllib.parse import urlsplit

try:
    from PIL import Image, ImageOps
except ImportError:
    if __name__ == "__main__":
        sys.exit(5)
    raise


MAX_SOURCE_BYTES = 8 * 1024 * 1024
MAX_PIXELS = 16000000


def fetch_image(url):
    address = urlsplit(url)
    if address.scheme != "https" or not address.hostname:
        raise ValueError("Expected an HTTPS URL")
    path = address.path + ("?" + address.query if address.query else "")
    # HTTPSConnection performs a single request; redirects never leave the validated host.
    connection = http.client.HTTPSConnection(address.hostname, timeout=8)
    try:
        headers = {"Accept": "image/png, image/jpeg", "User-Agent": "BandaStation-Library/1.0"}
        connection.request("GET", path, headers=headers)
        response = connection.getresponse()
        if response.status != 200:
            raise OSError("Host did not return an image")
        if int(response.getheader("Content-Length") or 0) > MAX_SOURCE_BYTES:
            raise ValueError("Image exceeds byte limit")
        data = response.read(MAX_SOURCE_BYTES + 1)
        if len(data) > MAX_SOURCE_BYTES:
            raise ValueError("Image exceeds byte limit")
        return data
    finally:
        connection.close()


def normalize_image(data, max_length):
    if not data.startswith((b"\x89PNG\r\n\x1a\n", b"\xff\xd8\xff")):
        raise ValueError("Expected PNG or JPEG")
    with Image.open(io.BytesIO(data)) as original:
        if original.format not in ("PNG", "JPEG") or original.width * original.height > MAX_PIXELS:
            raise ValueError("Unsupported image or too many pixels")
        original.thumbnail((320, 320), Image.LANCZOS)
        oriented = ImageOps.exif_transpose(original) if hasattr(ImageOps, "exif_transpose") else original
        image = oriented.convert("RGBA")
    # Preserve visible pixels only, including transparency. EXIF, profiles and additional frames stay out of books.
    image.info.clear()
    while True:
        output = io.BytesIO()
        image.save(output, format="PNG")
        encoded = base64.b64encode(output.getvalue())
        if len(encoded) <= max_length:
            return encoded
        if max(image.size) <= 1:
            raise ValueError("PNG does not fit")
        smaller = max(1, image.width * 3 // 4), max(1, image.height * 3 // 4)
        image.thumbnail(smaller, Image.LANCZOS)


def main():
    # Bound DNS resolution, slow streaming responses and decoder work, including on Windows.
    deadline = threading.Timer(20, os._exit, args=(4,))
    deadline.daemon = True
    deadline.start()
    try:
        job = Path(sys.argv[2])
        url = job.with_suffix(".url").read_text(encoding="utf-8-sig").strip()
        try:
            data = fetch_image(url)
        except socket.timeout:
            return 4
        except (http.client.HTTPException, OSError):
            return 2
        job.with_suffix(".txt").write_bytes(normalize_image(data, int(sys.argv[1])))
        return 0
    except (OSError, ValueError, SyntaxError, Image.DecompressionBombError):
        return 3
    finally:
        deadline.cancel()


if __name__ == "__main__":
    sys.exit(main())
