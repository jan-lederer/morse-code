"""Verify the actual Android PCM builder using the project's cached Kotlin compiler."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
cache = Path('/workspace/.data/docker-cache/gradle/caches/modules-2/files-2.1')
components = [
    ('org.jetbrains.kotlin', 'kotlin-compiler-embeddable'),
    ('org.jetbrains.kotlin', 'kotlin-stdlib'),
    ('org.jetbrains.kotlin', 'kotlin-script-runtime'),
    ('org.jetbrains.kotlin', 'kotlin-reflect'),
    ('org.jetbrains.kotlin', 'kotlin-daemon-embeddable'),
    ('org.jetbrains.kotlinx', 'kotlinx-coroutines-core-jvm'),
    ('org.jetbrains', 'annotations'),
]
jars = []
for group, name in components:
    matches = sorted((cache / group / name).glob('*/*/*.jar'))
    if not matches:
        raise SystemExit(f'Missing cached compiler dependency: {name}')
    jars.append(matches[-1])
java = '/opt/java/bin/java'
output = root / 'artifacts/signal-pattern-check.jar'
stdlib = jars[1]
subprocess.run([
    java, '-cp', ':'.join(map(str, jars)),
    'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler', '-no-stdlib', '-no-reflect',
    '-classpath', f'{stdlib}:{jars[-1]}', '-jvm-target', '17', '-d', str(output),
    str(root / 'android/app/src/main/kotlin/studio/dit/dit_morse/SignalPattern.kt'),
    str(root / 'tests/SignalPatternCheck.kt'),
], check=True)
subprocess.run([
    java, '-cp', f'{output}:{stdlib}', 'studio.dit.dit_morse.SignalPatternCheckKt',
    str(root / 'artifacts/native-signal-preview.wav'),
], check=True)
