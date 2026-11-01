import subprocess,time,json,signal,os
from pathlib import Path

def run(args,t=60):return subprocess.run(args,capture_output=True,text=True,timeout=t)
device=Path('device-id.txt').read_text().strip();bundle='it.planthead.fanta'
r=run(['xcrun','simctl','install',device,'build/ios/iphonesimulator/Runner.app'],180);assert r.returncode==0,'install_failed'
r=run(['xcrun','simctl','get_app_container',device,bundle,'data']);assert r.returncode==0
p=Path(r.stdout.strip())/'Documents';p.mkdir(exist_ok=True)
out=open('runtime-console-private.log','w');proc=subprocess.Popen(['xcrun','simctl','launch','--console','--terminate-running-process',device,bundle],stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
start=time.monotonic();shots=set();result=None
try:
 while time.monotonic()-start<420:
  request=p/'runtime-shot.txt'
  if request.exists():
   name=request.read_text()
   allowed=['held-before-content','held-visible','normal-visible','empty-timeout','stale-ignored','official-integration']
   assert name in allowed
   if name not in shots:
    r=run(['xcrun','simctl','io',device,'screenshot','evidence/'+name+'.png']);assert r.returncode==0
    shots.add(name);(p/'runtime-shot-ack.txt').write_text(name)
  report=p/'runtime-result.json'
  if report.exists():
   try:result=json.loads(report.read_text())
   except json.JSONDecodeError:pass
   if result and result.get('finished'):break
  time.sleep(.3)
finally:
 run(['xcrun','simctl','terminate',device,bundle]);out.close()
 try:proc.wait(timeout=10)
 except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL)
 if result:Path('evidence/runtime-result.json').write_text(json.dumps(result,indent=2))
 Path('evidence/runtime-host.json').write_text(json.dumps({'screenshotNames':sorted(shots),'elapsedSeconds':round(time.monotonic()-start),'reportCollected':result is not None},indent=2))
assert result and result.get('finished') and result.get('passed') and result.get('deterministicPassed'),'runtime_assertion_or_collection_failure'
assert len(shots)==6,'missing_screenshots'
