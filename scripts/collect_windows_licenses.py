"""Copy dependency licenses into the portable bundle without copying caches/data."""
import json
import os
import pathlib
import re
import shutil
import subprocess
import urllib.parse
import urllib.request

root = pathlib.Path(__file__).resolve().parents[1]
bundle = root / 'build/windows/x64/runner/Release'
destination = bundle / 'licenses'
destination.mkdir(exist_ok=True)

ffmpeg_command = shutil.which('ffmpeg')
if not ffmpeg_command:
    raise SystemExit('FFmpeg must be installed before packaging')
ffmpeg = pathlib.Path(ffmpeg_command).resolve()
if ffmpeg.stat().st_size < 1_000_000:
    # Chocolatey exposes a shim in bin; distribute the actual static executable.
    choco_tools = pathlib.Path(os.environ.get('ChocolateyInstall', r'C:\ProgramData\chocolatey')) / 'lib/ffmpeg/tools'
    ffmpeg = next(choco_tools.rglob('ffmpeg.exe'))
shutil.copy2(ffmpeg, bundle / 'ffmpeg.exe')
ffmpeg_root = ffmpeg.parent.parent
ffmpeg_license = next((file for file in ffmpeg_root.iterdir()
                       if file.name.upper() in ('LICENSE', 'LICENSE.TXT', 'COPYING', 'COPYING.TXT')), None)
if ffmpeg_license is None:
    raise SystemExit(f'FFmpeg license is missing in {ffmpeg_root}')
shutil.copy2(ffmpeg_license, destination / 'FFmpeg-LICENSE.txt')
readme = ffmpeg_root / 'README.txt'
if readme.is_file():
    shutil.copy2(readme, destination / 'FFmpeg-README.txt')
version = subprocess.check_output([str(ffmpeg), '-version'], text=True, encoding='utf8')
(destination / 'FFmpeg-build.txt').write_text(
    'Distribution: https://www.gyan.dev/ffmpeg/builds/\n'
    'Source: https://github.com/FFmpeg/FFmpeg\n\n' + version, encoding='utf8')
config_file = root / '.dart_tool/package_config.json'
packages = json.loads(config_file.read_text(encoding='utf8'))['packages']
for package in packages:
    uri = urllib.parse.urlsplit(package['rootUri'])
    package_root = (pathlib.Path(urllib.request.url2pathname(uri.path)) if uri.scheme == 'file'
                    else (config_file.parent / urllib.parse.unquote(package['rootUri'])).resolve())
    if not package_root.is_dir():
        continue
    if package['name'] == 'flutter':
        sdk_license = package_root.parents[1] / 'LICENSE'
        if sdk_license.is_file():
            shutil.copy2(sdk_license, destination / 'Flutter-LICENSE.txt')
    for file in package_root.iterdir():
        if file.is_file() and re.match(r'^(LICENSE|COPYING|COPYRIGHT)([._-].*)?$', file.name, re.I):
            shutil.copy2(file, destination / f"{package['name']}-{file.name}.txt")
for source, name in [(root / 'LICENSE', 'fqapp-GPL-3.0.txt'),
                     (root / 'build/windows/x64/packages/Microsoft.Web.WebView2/LICENSE.txt', 'WebView2-LICENSE.txt')]:
    if source.is_file():
        shutil.copy2(source, destination / name)
header = root / 'build/windows/x64/fqapp_mpv/include/mpv/client.h'
if header.is_file():
    notice = header.read_text(encoding='utf8').split('*/', 1)[0] + '*/\n'
    (destination / 'libmpv-notice.txt').write_text(notice, encoding='utf8')
(destination / 'libmpv-build.txt').write_text(
    'Full x86_64 libmpv 20261021-git-e471496c56\n'
    'Build scripts and source dependencies: https://github.com/shinchiro/mpv-winbuild-cmake/tree/20261021\n'
    'mpv source: https://github.com/mpv-player/mpv/tree/e471496c56\n'
    'Binary: https://github.com/shinchiro/mpv-winbuild-cmake/releases/tag/20261021\n'
    'Archive SHA256: efc719eff3dc5954b4a5efc800632808bcec01cc9034940dd14e5eb7fe9ea633\n', encoding='utf8')
print(f'Collected {len(list(destination.iterdir()))} license files')
