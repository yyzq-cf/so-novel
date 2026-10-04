#!/usr/bin/env python3
"""Strip launch4j-maven-plugin from pom.xml for Docker builds.

launch4j generates a Windows .exe; its bundled windres binary is amd64-only,
so arm64 QEMU builds fail with ENOENT. Docker only needs the jar, not .exe.
"""
import sys
from pathlib import Path

pom = Path("pom.xml")
c = pom.read_text()
i = c.find("com.akathist.maven.plugins.launch4j")
if i < 0:
    print("launch4j plugin not found, nothing to remove", file=sys.stderr)
    sys.exit(0)
s = c.rfind("<plugin>", 0, i)
e = c.find("</plugin>", i) + len("</plugin>")
if s < 0 or e < len("</plugin>"):
    print("ERROR: could not locate <plugin>...</plugin> bounds", file=sys.stderr)
    sys.exit(1)
print(f"Removing launch4j plugin block [{s}:{e}] ({e - s} bytes)", file=sys.stderr)
pom.write_text(c[:s] + c[e:])
print("Done.", file=sys.stderr)
