# 1C 8.2 Wine Platform Image

This image is a standalone legacy helper for 1C 8.2.19.130 batch checks. It is
not part of the main `1c-developer` runtime and should be published only through
the manual GitHub Actions workflow `Publish 1C 8.2 Wine image`.

Prepare the local distribution archive:

```bash
mkdir -p .local/1c/wine82-platform
cp .local/1c/platform/windows.rar .local/1c/wine82-platform/windows.rar
```

Build locally:

```bash
docker build --platform linux/amd64 \
  -f platform82-wine/Dockerfile \
  -t local/1c82-platform:8.2.19.130 .
```

Run `CheckConfig` for a `.cf` using a runtime-mounted `nethasp.ini`:

```bash
docker run --rm --platform linux/amd64 \
  -v "$PWD/config.cf":/workspace/config.cf:ro \
  -v "$PWD/out":/workspace/out \
  -v "$PWD/nethasp.ini":/run/secrets/nethasp.ini:ro \
  local/1c82-platform:8.2.19.130 \
  --cf /workspace/config.cf \
  --out-dir /workspace/out \
  --locale ru_RU \
  --nethasp /run/secrets/nethasp.ini
```

The runner uses the same pattern as the legacy `KonturOpentelemetry`
`piefile.check_config()` flow:

1. `CREATEINFOBASE "File=...;Locale=ru_RU;" /UseTemplate <cf>`
2. `CONFIG /CheckConfig ... /Out <file>`

The image does not contain `nethasp.ini`, license files, ITS credentials, or any
configuration under test.
