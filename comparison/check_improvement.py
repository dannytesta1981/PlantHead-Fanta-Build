"""Release gate: usable real DOM AND an unobstructed Flutter WebView."""
import json
from pathlib import Path
root=Path('evidence')
def read(label):
 data=json.loads((root/label/'breadcrumbs.json').read_text())
 samples=[r['sample'] for r in data['records'] if 'sample' in r]
 events=[e['event'] for r in data['records'] for e in r.get('callbacks',[])]
 launch=json.loads((root/label/'native-launch-status.json').read_text())
 assert len(samples)==24,label+': missing samples'
 assert launch['installExit']==0 and launch['probesFilePresent'] and launch['eventsFilePresent'],label+': missing execution'
 assert launch['screenshot90Exit']==0,label+': missing rendering proof'
 return samples,events
def shown(s):return s.get('renderable') is True and s.get('webPageVisible') is True and s.get('errorOverlayVisible') is False and s.get('loadingOverlayVisible') is False
base,be=read('baseline-held');fixed,fe=read('fixed-held');natural,ne=read('fixed-natural')
baseline_blocked=all(s.get('renderable') is True and (s.get('errorOverlayVisible') or s.get('loadingOverlayVisible')) for s in base[-3:])
fixed_visible=all(shown(s) for s in fixed[-3:]) and all(s.get('naturalStop') is False for s in fixed)
natural_visible=all(shown(s) for s in natural[-3:]) and all(s.get('naturalStop') is True for s in natural)
result={'baselineUsableDOMObstructed':baseline_blocked,'fixedUsableDOMShownWithoutLoadStop':fixed_visible and 'stop' not in fe,'fixedNaturalContentShown':natural_visible,'loginAttempted':False,'allSamplesCollected':True}
result['improvementConfirmed']=all(result[k] for k in ['baselineUsableDOMObstructed','fixedUsableDOMShownWithoutLoadStop','fixedNaturalContentShown'])
(root/'IMPROVEMENT.json').write_text(json.dumps(result,indent=2))
assert result['improvementConfirmed'],'No verified improvement: do not compile IPA'
