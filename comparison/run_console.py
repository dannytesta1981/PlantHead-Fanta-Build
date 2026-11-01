"""Observe the simulator app directly, without a VM-service driver handshake."""
import json, os, signal, subprocess, sys, time
from pathlib import Path
device, version, label, mode = sys.argv[1:]
directory = Path('evidence') / label
logfile = Path(label + '-driver.log')
bundle = 'it.planthead.fanta'
def bounded(args, timeout=30, text=False):
    try:
        return subprocess.run(args,capture_output=True,timeout=timeout,text=text)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(args,124,stdout='' if text else b'',stderr='' if text else b'')
install = bounded(['xcrun','simctl','install',device,str(Path(version)/'build/ios/iphonesimulator/Runner.app')],timeout=180)
result = {'installExit': install.returncode, 'observationWindowSeconds': 300, 'naturalStop': mode == 'natural'}
result['installTimeout'] = install.returncode == 124
if install.returncode == 0:
    with logfile.open('w') as out:
        container = bounded(['xcrun','simctl','get_app_container',device,bundle,'data'],text=True)
        if container.returncode != 0: raise RuntimeError('test_container_unavailable')
        docs = Path(container.stdout.strip())/'Documents'
        docs.mkdir(parents=True,exist_ok=True)
        (docs/'ph-comparison-mode.txt').write_text(mode)
        process = subprocess.Popen(['xcrun','simctl','launch','--console','--terminate-running-process',device,bundle],stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
        start = time.monotonic()
        captured = set()
        while time.monotonic()-start < 300:
            for second in [45,90]:
                if second not in captured and time.monotonic()-start >= second:
                    screenshot = bounded(['xcrun','simctl','io',device,'screenshot',str(directory/('at-'+str(second)+'s.png'))])
                    result['screenshot'+str(second)+'Exit'] = screenshot.returncode
                    captured.add(second)
            probes = docs/'ph-comparison-probes.log'
            if 90 in captured and probes.exists() and '"phase":"finished"' in probes.read_text(): break
            time.sleep(1)
        result['elapsedMs'] = round((time.monotonic()-start)*1000)
        result['consoleExitBeforeTermination'] = process.poll()
        container = bounded(['xcrun','simctl','get_app_container',device,bundle,'data'],text=True)
        result['containerLookupExit'] = container.returncode
        persisted = Path(label+'-persisted.log')
        persisted.write_text('')
        for kind in ['probes','events']:
            source = Path(container.stdout.strip())/'Documents'/('ph-comparison-'+kind+'.log')
            present = container.returncode == 0 and source.is_file()
            result[kind+'FilePresent'] = present
            if present:
                with persisted.open('a') as target:target.write(source.read_text())
        stop = bounded(['xcrun','simctl','terminate',device,bundle])
        result['terminateExit'] = stop.returncode
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        result['consoleExit'] = process.returncode
(directory/'native-launch-status.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result))
