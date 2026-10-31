"""Export only closed-category breadcrumbs from the unauthenticated test log."""
import json, re, sys
from pathlib import Path
raw=Path(sys.argv[1]).read_text(errors='replace') if Path(sys.argv[1]).exists() else ''
allowed={
 'event':set('startup web_created web_visible web_hidden web_load_start web_load_stop web_history web_resource_error web_http_error web_timeout web_dom_ready web_dom_empty web_probe_error web_process_terminated web_retry web_navigation_allow web_navigation_external web_navigation_block web_paused page_start page_loaded history http_error network_error extract_ok extract_error origin_rejected navigation_requested navigation_missing session_cleared resumed web_open native_open web_app_command web_request web_server_redirect web_commit web_main_404 web_popup_requested web_popup_closed web_access_requested web_access_unavailable web_access_visible login_form_observed'.split()),
 'route':set('unknown blank official_home official_login official_other identity external blocked'.split()),
 'from':set('unknown blank official_home official_login official_other identity external blocked'.split()),
 'cause':set('unknown web_link web_form web_history web_reload web_other server_redirect app_initial_home app_home app_retry_home app_reload app_control app_back app_access popup'.split()),
 'window':{'main','popup','unknown'},'method':{'get','post','other','unknown'},
 'category':set('unknown main_frame subframe cancelled creation document webkit'.split())}
events=[];phases=[]
for line in raw.splitlines():
 if 'PH112_EVENT_JSON:' in line:
  try:d=json.loads(line.split('PH112_EVENT_JSON:',1)[1].strip())
  except (ValueError,TypeError):continue
  if not isinstance(d,dict):continue
  e={k:v for k,v in d.items() if k in allowed and isinstance(v,str) and v in allowed[k]}
  for k in ['navigation','httpStatus','code','count']:
   if isinstance(d.get(k),int) and -9999<=d[k]<=1000000:e[k]=d[k]
  if 'event' in e:events.append(e)
 if 'PH112_PHASE:' in line:
  p=line.split('PH112_PHASE:',1)[1].strip()
  if p in {'started','probing_initial_document','initial_document_probed','existing_link_followed','recovery_started','probing_recovery_document','recovery_document_probed','finished'}:phases.append(p)
print(json.dumps({'rawMessagesExported':False,'phases':phases,'events':events[-300:],
 'driverLogPresent':bool(raw),'compileErrorDetected':bool(re.search(r'Failed to build iOS app|Error \(Xcode\)|error: ',raw)),
 'driverAllTestsPassed':bool(re.search(r'All tests passed\.',raw))},indent=2))
