"""Observe the simulator app directly, without a VM-service driver handshake."""
import json, os, signal, subprocess, sys, time
from pathlib import Path
device, version = sys.argv[1:]
directory = Path('evidence') / version
logfile = Path(version + '-driver.log')
bundle = 'it.planthead.fanta'
install = subprocess.run(['xcrun','simctl','install',device,str(Path(version)/'build/ios/iphonesimulator/Runner.app')],capture_output=True,timeout=60)
result = {'installExit': install.returncode, 'observationWindowSeconds': 90}
if install.returncode == 0:
    with logfile.open('w') as out:
        process = subprocess.Popen(['xcrun','simctl','launch','--console','--terminate-running-process',device,bundle],stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
        start = time.monotonic()
        captured = False
        while time.monotonic()-start < 90:
            if not captured and time.monotonic()-start >= 45:
                screenshot = subprocess.run(['xcrun','simctl','io',device,'screenshot',str(directory/'during-observation.png')],capture_output=True,timeout=30)
                result['screenshotExit'] = screenshot.returncode
                captured = True
            time.sleep(1)
        result['consoleExitBeforeTermination'] = process.poll()
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
