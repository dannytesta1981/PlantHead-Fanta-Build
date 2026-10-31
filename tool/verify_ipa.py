"""Verify the actual unsigned iPhone application in a built IPA archive."""
import hashlib
import json
import plistlib
import struct
import sys
import zipfile
from pathlib import Path

ipa=Path(sys.argv[1])
with zipfile.ZipFile(ipa) as z:
    assert z.testzip() is None, 'ZIP integrity failure'
    names=z.namelist()
    plists=[n for n in names if n.startswith('Payload/') and n.endswith('.app/Info.plist') and n.count('/')==2]
    assert len(plists)==1, 'Expected one Payload/*.app application'
    plist=plistlib.loads(z.read(plists[0]))
    app=plists[0].removesuffix('Info.plist')
    assert plist['CFBundleIdentifier']=='it.planthead.fanta'
    assert plist['CFBundleShortVersionString']=='1.1.1'
    assert plist['CFBundleVersion']=='3'
    assert plist['CFBundlePackageType']=='APPL'
    assert 'iPhoneOS' in plist['CFBundleSupportedPlatforms']
    binaries=[app+plist['CFBundleExecutable'],app+'Frameworks/App.framework/App',app+'Frameworks/Flutter.framework/Flutter']
    checks=[]
    for name in binaries:
        data=z.read(name)
        magic=data[:4]
        if magic==b'\xcf\xfa\xed\xfe':
            cpu=struct.unpack_from('<I',data,4)[0]
            assert cpu==0x100000c, f'{name}: not ARM64 Mach-O'
        elif magic==b'\xca\xfe\xba\xbe':
            n=struct.unpack_from('>I',data,4)[0]
            cpus=[struct.unpack_from('>I',data,8+i*20)[0] for i in range(n)]
            assert 0x100000c in cpus, f'{name}: no ARM64 slice'
        else:
            raise AssertionError(f'{name}: invalid Mach-O magic {magic.hex()}')
        assert len(data)>10000, f'{name}: unexpected binary size'
        checks.append({'file':name,'bytes':len(data),'arm64_macho':True})
    for asset in ['navigation.js', 'data_bridge.js']:
        assets=[n for n in names if n.endswith('/flutter_assets/assets/'+asset)]
        assert len(assets)==1
        assert z.read(assets[0])==Path(__file__).resolve().parents[1].joinpath('assets',asset).read_bytes()
    print(json.dumps({'status':'PASS','ipa':ipa.name,'bytes':ipa.stat().st_size,
        'sha256':hashlib.sha256(ipa.read_bytes()).hexdigest(),
        'bundle_id':plist['CFBundleIdentifier'],'version':plist['CFBundleShortVersionString'],
        'build':plist['CFBundleVersion'],
        'minimum_os':plist['MinimumOSVersion'],'sdk':plist.get('DTSDKName'),
        'platform':plist['CFBundleSupportedPlatforms'],'binaries':checks,
        'navigation_asset_matches_source':True,'data_bridge_asset_matches_source':True},indent=2))
