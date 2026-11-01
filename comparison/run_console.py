"""Observe the simulator app directly, without a VM-service driver handshake."""
import json, os, signal, subprocess, sys, time
from pathlib import Path
device, version = sys.argv[1:]
directory = Path('evidence') / version
logfile = Path(version + '-driver.log')
bundle = 'it.planthead.fanta'
install = subprocess.run(['xcrun','simctl','install',device,str(Path(version)/'build/ios/iphonesimulator/Runner.app')],capture_output=True,timeout=60)
result = {'installExit': install.returncode, 'observationWindowSeconds': 140}
if install.returncode == 0:
    with logfile.open('w') as out:
        process = subprocess.Popen(['xcrun','simctl','launch','--console','--terminate-running-process',device,bundle],stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
        start = time.monotonic()
        captured = False
        while time.monotonic()-start < 140:
            if not captured and time.monotonic()-start >= 45:
                screenshot = subprocess.run(['xcrun','simctl','io',device,'screenshot',str(directory/'during-observation.png')],capture_output=True,timeout=30)
                result['screenshotExit'] = screenshot.returncode
                captured = True
            time.sleep(1)
        result['consoleExitBeforeTermination'] = process.poll()
        container = subprocess.run(['xcrun','simctl','get_app_container',device,bundle,'data'],capture_output=True,text=True,timeout=30)
        result['containerLookupExit'] = container.returncode
        persisted = Path(version+'-persisted.log')
        persisted.write_text('')
        for kind in ['probes','events']:
            source = Path(container.stdout.strip())/'Documents'/('ph-comparison-'+kind+'.log')
            present = container.returncode == 0 and source.is_file()
            result[kind+'FilePresent'] = present
            if present:
                with persisted.open('a') as target:target.write(source.read_text())
        stop = subprocess.run(['xcrun','simctl','terminate',device,bundle],capture_output=True,timeout=30)
        result['terminateExit'] = stop.returncode
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        result['consoleExit'] = process.returncode
(directory/'native-launch-status.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result))
