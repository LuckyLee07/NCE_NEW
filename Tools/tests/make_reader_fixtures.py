"""Make temporary invalid archives for the native ZIP reader regression tests."""

from pathlib import Path
import struct
import sys
import warnings
import zipfile

root = Path(sys.argv[1])
for case in ("missing", "corrupt", "duplicate", "oversized", "invalidtext", "badcrc", "missingentry"):
    directory = root / case
    directory.mkdir(parents=True)
    if case == "missing":
        continue
    path = directory / "book1.zip"
    if case == "corrupt":
        path.write_bytes(b"not a ZIP file")
        continue
    with zipfile.ZipFile(path, "w") as archive:
        name = "lrc/N1_L1_sentence.lrc" if case == "invalidtext" else "mp3/N1_L1_sentence.mp3"
        if case == "missingentry":
            name = "mp3/N1_L2_sentence.mp3"
        data = b"test-audio"
        if case == "oversized":
            data = b"a" * (4 * 1024 * 1024 + 1)
        elif case == "invalidtext":
            data = b"\xff"
        archive.writestr(name, data)
        if case == "duplicate":
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                archive.writestr(name, data)
    if case == "badcrc":
        data = bytearray(path.read_bytes())
        name_length, extra_length = struct.unpack_from("<HH", data, 26)
        data[30 + name_length + extra_length] ^= 1
        path.write_bytes(data)
