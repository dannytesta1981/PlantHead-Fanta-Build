import json,sys
from pathlib import Path
keys=set('phase sample samples callbacks ms event commitSeen ready bodyPresent bodySized bodyHasContent resourceCompleted resourceHttpFailure resourceStatusUnknown counters jsErrors unhandledRejections resourceErrors scriptErrors styleErrors imageErrors probe'.split())
values=set('started finished created start stop dom_probe timeout commit main_error subframe_error main_http_error subframe_http_error terminated loading interactive complete unknown no_result failed_or_timeout'.split())
def clean(x):
 if isinstance(x,dict):return {k:clean(v) for k,v in x.items() if k in keys}
 if isinstance(x,list):return [clean(v) for v in x[:500]]
 if isinstance(x,bool) or isinstance(x,(int,float)):return x
 return x if isinstance(x,str) and x in values else 'unknown'
p=Path(sys.argv[1]);records=[]
if p.exists():
 for line in p.read_text(errors='replace').splitlines():
  if 'PHCMP:' not in line:continue
  try:records.append(clean(json.loads(line.split('PHCMP:',1)[1])))
  except ValueError:pass
print(json.dumps({'driverLogPresent':p.exists(),'records':records,'samplesCollected':sum('sample'in x for x in records)},indent=2))
