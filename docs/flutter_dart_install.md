# Flutter + Dart install (Ubuntu)

This project is developed with Flutter and Dart.

## Install latest stable Flutter (includes Dart)

```bash
cd /tmp
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json \
  | python3 -c "import sys, json; d=json.load(sys.stdin); h=d['current_release']['stable']; r=next(x for x in d['releases'] if x['hash']==h); print(d['base_url'] + '/' + r['archive'])" \
  | xargs -I{} curl -fL "{}" -o flutter.tar.xz
sudo rm -rf /opt/flutter
sudo mkdir -p /opt
sudo tar -xJf flutter.tar.xz -C /opt
sudo chown -R "$USER":"$USER" /opt/flutter
sudo ln -sf /opt/flutter/bin/flutter /usr/local/bin/flutter
sudo ln -sf /opt/flutter/bin/dart /usr/local/bin/dart
```

## Verify

```bash
flutter --version
dart --version
```

If you get a Git safe-directory warning, run:

```bash
git config --global --add safe.directory /opt/flutter
```
