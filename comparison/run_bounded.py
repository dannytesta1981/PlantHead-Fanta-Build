"""Bound test tooling, preserve private raw logs, export only closed stages."""
import json, os, signal, subprocess, sys
from pathlib import Path
seconds, logfile, statusfile, cwd, *command = sys.argv[1:]
timed_out = False
with open(logfile, 'w') as out:
    process = subprocess.Popen(command, cwd=cwd, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        code = process.wait(timeout=int(seconds))
    except subprocess.TimeoutExpired:
        timed_out = True
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        code = 124
raw = Path(logfile).read_text(errors='replace')
signatures = {
    'vm_service_announced': ['Dart VM Service is listening', 'VM Service URL on device'],
    'vm_connect_attempted': ['Connecting to VM Service', 'Connecting to service protocol'],
    'vm_connected': ['Successfully connected to service protocol', 'Connected to the VM Service'],
    'test_started': ['PHCMP:{"phase":"started"}'],
    'test_finished': ['PHCMP:{"phase":"finished"'],
    'test_failed': ['Some tests failed', 'Test failed', '[E]'],
    'launch_failed': ['Error launching application', 'Could not launch', 'Failed to launch'],
    'build_failed': ['Could not build the application', 'Error (Xcode)', 'BUILD FAILED'],
}
result = {'exitCode': code, 'toolTimeout': timed_out,
          'stages': {key: any(s in raw for s in values) for key, values in signatures.items()}}
Path(statusfile).write_text(json.dumps(result, indent=2))
print(json.dumps(result))
sys.exit(code)
