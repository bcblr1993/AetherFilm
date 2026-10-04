#!/usr/bin/env python3
"""Own non-root SMB3-required fixture, numeric wire observation, no secret logs."""
from pathlib import Path
import argparse, collections, hashlib, http.server, json, os, pwd, secrets, shutil, signal, socket, stat, subprocess, tempfile, threading, time
try:
    from Cryptodome.Hash import MD4
except ImportError:
    MD4=None

class Observation:
    def __init__(self):
        self.condition=threading.Condition()
        self.stop=False
        self.hold=False
        self.values=collections.Counter()
        self.commands=collections.Counter()
        self.dialects=collections.Counter()
        self.completedCases=set()
    def snapshot(self):
        with self.condition:
            return {k:self.values[k] for k in ['acceptedConnections','encryptedClientFrames','encryptedServerFrames','plaintextReadRequests','heldEncryptedServerFrames','clientBytes','serverBytes','plainClientFrames','plainServerFrames','partialFrames','malformedPlaintextFrames']} | {
                'plaintextCommandCounts':dict(self.commands),'negotiatedDialectCounts':dict(self.dialects),'completedCases':sorted(self.completedCases)}
    def capture(self,payload,direction):
        # Only fixed integers survive this method. Complete packet bytes are only forwarded.
        encrypted=payload[:4]==b'\xfdSMB'
        with self.condition:
            self.values[direction+'Bytes']+=len(payload)
            if encrypted:self.values['encrypted'+direction.title()+'Frames']+=1
            elif payload[:4]==b'\xfeSMB':
                self.values['plain'+direction.title()+'Frames']+=1
                offset=0
                while True:
                    if len(payload)-offset<64 or payload[offset:offset+4]!=b'\xfeSMB' or int.from_bytes(payload[offset+4:offset+6],'little')!=64:
                        self.values['malformedPlaintextFrames']+=1;break
                    command=int.from_bytes(payload[offset+12:offset+14],'little')
                    following=int.from_bytes(payload[offset+20:offset+24],'little')
                    self.commands[direction+':'+str(command)]+=1
                    if direction=='client' and command==8:self.values['plaintextReadRequests']+=1
                    if direction=='server' and command==0 and len(payload)-offset>=70:
                        self.dialects[str(int.from_bytes(payload[offset+68:offset+70],'little'))]+=1
                    if following==0:break
                    if following<64 or following%8!=0 or offset+following+64>len(payload):
                        self.values['malformedPlaintextFrames']+=1;break
                    offset+=following
        return encrypted

class Proxy:
    def __init__(self,target,observation,slow=False):
        self.target=target;self.obs=observation;self.slow=slow
        self.listener=socket.socket();self.listener.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
        self.listener.bind(('127.0.0.1',0));self.listener.listen(16);self.listener.settimeout(.2)
        self.port=self.listener.getsockname()[1];self.active=set();self.lock=threading.Lock();self.threads=[]
        self.thread=threading.Thread(target=self.accept,daemon=True);self.thread.start()
    def accept(self):
        while not self.obs.stop:
            try:client,_=self.listener.accept()
            except socket.timeout:continue
            except OSError:break
            try:server=socket.create_connection(('127.0.0.1',self.target),timeout=3)
            except OSError:client.close();continue
            client.settimeout(.2);server.settimeout(.2)
            with self.obs.condition:self.obs.values['acceptedConnections']+=1
            with self.lock:self.active.update([client,server])
            for incoming,outgoing,direction in [(client,server,'client'),(server,client,'server')]:
                thread=threading.Thread(target=self.pipe,args=(incoming,outgoing,direction),daemon=True)
                self.threads.append(thread);thread.start()
    def exact(self,source,count):
        result=bytearray()
        while len(result)<count and not self.obs.stop:
            try:chunk=source.recv(count-len(result))
            except socket.timeout:continue
            if not chunk:return None
            result.extend(chunk)
        return bytes(result) if len(result)==count else None
    def pipe(self,source,dest,direction):
        try:
            while not self.obs.stop:
                header=self.exact(source,4)
                if header is None:break
                size=int.from_bytes(header[1:4],'big')
                if header[0]!=0 or size>32*1024*1024:break
                payload=self.exact(source,size)
                if payload is None:
                    with self.obs.condition:self.obs.values['partialFrames']+=1
                    break
                encrypted=self.obs.capture(payload,direction)
                if self.slow and direction=='server' and encrypted:
                    with self.obs.condition:
                        if self.obs.hold:
                            self.obs.values['heldEncryptedServerFrames']+=1
                            self.obs.condition.notify_all()
                        while self.obs.hold and not self.obs.stop:self.obs.condition.wait(.1)
                if self.obs.stop:break
                dest.sendall(header+payload)
                del payload
        except OSError:pass
        finally:
            # Close only this fixture's accepted socket pair.
            for stream in (source,dest):
                try:stream.shutdown(socket.SHUT_RDWR)
                except OSError:pass
                stream.close()
                with self.lock:self.active.discard(stream)
    def close(self):
        self.listener.close()
        with self.lock:sockets=list(self.active)
        for stream in sockets:
            try:stream.shutdown(socket.SHUT_RDWR)
            except OSError:pass
            stream.close()
        self.thread.join(2)
        for thread in self.threads:thread.join(1)

def free_port():
    with socket.socket() as stream:
        stream.bind(('127.0.0.1',0));return stream.getsockname()[1]

def resolve_samba(prefix):
    if prefix:
        root=Path(prefix).resolve()
        choices=[(root/'sbin/samba-dot-org-smbd',root/'bin/testparm'),(root/'sbin/smbd',root/'bin/testparm')]
    else:
        choices=[]
        # macOS also has Apple's unrelated /usr/sbin/smbd. Try every strict-version candidate.
        for name in ['samba-dot-org-smbd','smbd']:
            found=shutil.which(name)
            if found:
                daemon=Path(found).resolve()
                choices.append((daemon,daemon.parent.parent/'bin/testparm'))
    seen=set()
    for daemon,testparm in choices:
        daemon=daemon.resolve();testparm=testparm.resolve()
        if str(daemon) in seen or not daemon.is_file() or not testparm.is_file():continue
        seen.add(str(daemon))
        try:
            valid=True
            for program in (daemon,testparm):
                version=subprocess.run([str(program),'--version'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=20)
                if version.returncode!=0 or version.stdout.strip()!=b'Version 4.25.0':valid=False;break
            if valid:return str(daemon),str(testparm)
        except (OSError,subprocess.TimeoutExpired):continue
    return None

def normalize_owned_permissions(base):
    changed=collections.Counter()
    for owned in [base,*base.rglob('*')]:
        metadata=owned.lstat()
        if stat.S_ISLNK(metadata.st_mode):raise RuntimeError('unexpected own fixture symlink')
        if stat.S_ISDIR(metadata.st_mode):
            if metadata.st_mode&0o777!=0o700:changed['directories']+=1
            owned.chmod(0o700)
        elif stat.S_ISREG(metadata.st_mode):
            if metadata.st_mode&0o777!=0o600:changed['regularFiles']+=1
            owned.chmod(0o600)
    return dict(changed)

def owned_group_exists(group):
    try:os.killpg(group,0);return True
    except ProcessLookupError:return False
    except PermissionError:return True

def stop_owned_session(child,grace=5,forced=5):
    # Both callers use start_new_session=True; this exact group belongs to their Popen.
    # The parent can exit while its same-group descendants still hold inherited pipes.
    output,errors=b'',b''
    for action,budget in [(signal.SIGTERM,grace),(signal.SIGKILL,forced)]:
        try:os.killpg(child.pid,action)
        except ProcessLookupError:pass
        except PermissionError:continue
        deadline=time.monotonic()+budget
        try:output,errors=child.communicate(timeout=max(.001,deadline-time.monotonic()))
        except subprocess.TimeoutExpired as timeout:
            output,errors=timeout.output or b'',timeout.stderr or b''
        while owned_group_exists(child.pid) and time.monotonic()<deadline:time.sleep(.02)
        if child.poll() is not None and not owned_group_exists(child.pid):return output,errors,True
    # A detached descendant is not permission to scan or signal any unrelated group.
    # Close only these owned pipe descriptors, and report cleanup failure explicitly.
    for stream in (child.stdout,child.stderr):
        if stream:stream.close()
    if child.poll() is None:
        child.kill()
        try:child.wait(timeout=1)
        except subprocess.TimeoutExpired:pass
    return output,errors,False

def main():
    parser=argparse.ArgumentParser(description='Opt-in preinstalled Samba 4.25.0 SMB3 encryption fixture. Never installs or changes system SMB.')
    parser.add_argument('--samba-prefix',type=Path,help='Optional existing Samba installation prefix; otherwise PATH')
    parser.add_argument('--repo-root',type=Path,default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--media-folder',type=Path,required=True,help='Generated fixtures containing clip-h264.mp4')
    parser.add_argument('--result',type=Path,required=True,help='New numeric-only JSON result; existing files are refused')
    parser.add_argument('command',nargs=argparse.REMAINDER,help='Optional command after --; default actual FilmSources Swift test suite')
    args=parser.parse_args()
    if args.result.exists():parser.error('result already exists; preserve prior evidence')
    if os.getuid()==0:parser.error('fixture must run as non-root')
    if MD4 is None:parser.error('preinstalled test requirement pycryptodomex unavailable; no automatic installation')
    samba=resolve_samba(args.samba_prefix)
    if not samba:parser.error('preinstalled Samba 4.25.0/testparm unavailable; no automatic installation')
    videoPath=(args.media_folder/'clip-h264.mp4').resolve()
    if not (args.media_folder/'clip-h264.mp4').is_file() or (args.media_folder/'clip-h264.mp4').is_symlink():parser.error('generated H264 fixture unavailable or symlink')
    video=videoPath.read_bytes()
    if not 0<len(video)<=16*1024*1024:parser.error('fixture exceeds product read limit')
    package=args.repo_root/'Packages/AetherFilmKit'
    if not (package/'Package.swift').is_file():parser.error('formal shared package unavailable')
    childCommand=args.command
    if childCommand[:1]==['--']:childCommand=childCommand[1:]
    if not childCommand:childCommand=['swift','test','--package-path',str(package),'--filter','SMB3EncryptionIntegrationTests']
    args.result.parent.mkdir(parents=True,exist_ok=True)
    report={'schemaVersion':1,'completed':False,'sambaVersion':'4.25.0','nonroot':True,
            'globalServicesChanged':False,'globalConfigChanged':False,'unixPasswordChanged':False,
            'HomebrewInstallOrUpgradePerformed':False,'credentialsInArgvOrEnvironmentOrArtifacts':False,
            'wireRawPacketsPersisted':False,'serverMinimumDialect':0x300,'serverMaximumDialect':0x311,'serverEncryptionRequired':True}
    obs=Observation();proxies=[];server=None;bootstrap=None;child=None;httpThread=None
    oldmask=os.umask(0o077)
    try:
        with tempfile.TemporaryDirectory(prefix='AetherFilmSMB3-') as temporary:
            base=Path(temporary);base.chmod(0o700)
            try:
                for name in ['private','state','cache','lock','pid','share']:(base/name).mkdir(mode=0o700)
                user=pwd.getpwuid(os.getuid()).pw_name
                password=secrets.token_urlsafe(32)
                hashNT=MD4.new(password.encode('utf-16le')).hexdigest().upper()
                passdb=base/'private/smbpasswd'
                passdb.write_text(f'{user}:{os.getuid()}:'+'X'*32+f':{hashNT}:[U          ]:LCT-{int(time.time()):08X}:\n');passdb.chmod(0o600)
                del hashNT
                accountmap=base/'private/user-map'
                accountmap.write_text(f'{user} = aetherfilm-smb3-fixture\n');accountmap.chmod(0o600)
                payload=bytes(i%251 for i in range(1_048_649))
                (base/'share/sample.bin').write_bytes(payload)
                (base/'share/中文目录').mkdir(mode=0o700)
                (base/'share/中文目录/测试影片.mp4').write_bytes(video)
                port=free_port();cfg=base/'smb.conf'
                cfg.write_text(f'''[global]
server role = standalone server
security = user
workgroup = WORKGROUP
netbios name = AFSMB3FIXTURE
interfaces = 127.0.0.1
bind interfaces only = yes
smb ports = {port}
disable netbios = yes
server min protocol = SMB3_00
server max protocol = SMB3_11
server smb encrypt = required
unix password sync = no
pam password change = no
obey pam restrictions = no
passdb backend = smbpasswd:{passdb}
username map = {accountmap}
private dir = {base/'private'}
state directory = {base/'state'}
cache directory = {base/'cache'}
lock directory = {base/'lock'}
pid directory = {base/'pid'}
ncalrpc dir = {base/'private/ncalrpc'}
log file = /dev/null
logging = file
log level = 0
load printers = no
printcap name = /dev/null
map to guest = Never
create mask = 0600
force create mode = 0600
directory mask = 0700
force directory mode = 0700
[AFTEST]
path = {base/'share'}
read only = yes
guest ok = no
valid users = {user}
''');cfg.chmod(0o600)
                checked=subprocess.run([samba[1],'-s',str(cfg)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=20)
                report['testparmExit']=checked.returncode
                del checked
                if report['testparmExit']!=0:raise RuntimeError('own fixture configuration rejected')
                server=subprocess.Popen([samba[0],'-F','--no-process-group','--configfile='+str(cfg)],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,start_new_session=True,umask=0o077)
                deadline=time.monotonic()+8;ready=False
                while time.monotonic()<deadline and server.poll() is None:
                    try:
                        with socket.create_connection(('127.0.0.1',port),timeout=.2):ready=True;break
                    except OSError:time.sleep(.05)
                if not ready:raise RuntimeError('own fixture startup failed')
                report['configuredPrivateDirectories700']=all((base/name).stat().st_mode&0o777==0o700 for name in ['private','state','cache','lock','pid'])
                report['hashedPassdb600']=passdb.stat().st_mode&0o777==0o600
                proxies=[Proxy(port,obs),Proxy(port,obs,slow=True)]
                class Handler(http.server.BaseHTTPRequestHandler):
                    def log_message(self,*args):pass
                    def send_json(self,value):
                        data=json.dumps(value).encode();self.send_response(200)
                        self.send_header('Content-Type','application/json');self.send_header('Cache-Control','no-store')
                        self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
                    def do_GET(self):
                        if self.path=='/configuration':self.send_json(configuration)
                        elif self.path=='/control':self.send_json(obs.snapshot())
                        else:self.send_error(404)
                    def do_POST(self):
                        if self.path!='/control':self.send_error(404);return
                        try:
                            size=int(self.headers.get('Content-Length','0'))
                            if not 0<size<=1024:raise ValueError()
                            value=json.loads(self.rfile.read(size))
                            with obs.condition:
                                action=value.get('action')
                                if action=='caseComplete':
                                    code=value.get('code')
                                    if type(code) is not int or not 1<=code<=8:raise ValueError()
                                    obs.completedCases.add(code)
                                elif action in ('hold','release'):
                                    obs.hold=action=='hold';obs.condition.notify_all()
                                else:raise ValueError()
                            self.send_json(obs.snapshot())
                        except (ValueError,TypeError):self.send_error(400)
                bootstrap=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler);bootstrap.daemon_threads=True
                configuration={'port':proxies[0].port,'slowPort':proxies[1].port,'username':'aetherfilm-smb3-fixture','password':password,'share':'AFTEST',
                    'controlURL':f'http://127.0.0.1:{bootstrap.server_port}/control','payloadSize':len(payload),'payloadSHA256':hashlib.sha256(payload).hexdigest(),
                    'videoSize':len(video),'videoSHA256':hashlib.sha256(video).hexdigest()}
                httpThread=threading.Thread(target=bootstrap.serve_forever,daemon=True);httpThread.start()
                environment=dict(os.environ)
                for key in list(environment):
                    if key.startswith('AETHERFILM_SMB_') or key=='AETHERFILM_SMB3_BOOTSTRAP_URL':environment.pop(key,None)
                environment['AETHERFILM_SMB3_BOOTSTRAP_URL']=f'http://127.0.0.1:{bootstrap.server_port}/configuration'
                child=subprocess.Popen(childCommand,env=environment,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True,umask=0o077)
                report['ownedTestPID']=child.pid
                try:output,errors=child.communicate(timeout=180)
                except subprocess.TimeoutExpired:
                    output,errors,stopped=stop_owned_session(child)
                    report['ownedTestProcessGroupStopped']=stopped;report['testTimeout']=True
                report['testExit']=child.returncode;report['testStdoutBytes']=len(output);report['testStderrBytes']=len(errors)
                # No arbitrary library/testing logs or configuration/credentials are persisted.
                del output,errors
                report['wire']=obs.snapshot()
                report['allGeneratedDirectories700DuringRunning']=all(path.stat().st_mode&0o777==0o700 for path in base.rglob('*') if path.is_dir())
                report['allGeneratedRegularFiles600DuringRunning']=all(path.stat().st_mode&0o777==0o600 for path in base.rglob('*') if path.is_file())
                wire=report['wire']
                report['completed']=child.returncode==0 and wire['completedCases']==list(range(1,9)) and wire['plaintextReadRequests']==0 and wire['malformedPlaintextFrames']==0 and wire['encryptedClientFrames']>0 and wire['encryptedServerFrames']>0 and set(wire['negotiatedDialectCounts'])=={'785'}
            finally:
                with obs.condition:obs.hold=False;obs.stop=True;obs.condition.notify_all()
                if child and not report.get('ownedTestProcessGroupStopped',False):
                    output,errors,stopped=stop_owned_session(child)
                    report['ownedTestProcessGroupStopped']=stopped
                    del output,errors
                for proxy in proxies:proxy.close()
                if bootstrap:bootstrap.shutdown();bootstrap.server_close()
                if httpThread:httpThread.join(2)
                if server:
                    _,errors,stopped=stop_owned_session(server)
                    report['serverStderrBytes']=len(errors);del errors
                    report['ownedServerStopped']=server.poll() is not None
                    report['ownedServerProcessGroupStopped']=stopped
                report['root700Isolation']=base.stat().st_mode&0o777==0o700
                report['afterChildStopModesNormalized']=normalize_owned_permissions(base)
                report['finalDirectories700']=all(path.stat().st_mode&0o777==0o700 for path in [base,*base.rglob('*')] if path.is_dir())
                report['finalRegularFiles600']=all(path.stat().st_mode&0o777==0o600 for path in base.rglob('*') if path.is_file())
        report['temporaryDirectoryRemoved']=not base.exists()
        report['completed']=report['completed'] and report.get('ownedTestProcessGroupStopped',False) and report.get('ownedServerProcessGroupStopped',False) and report['root700Isolation'] and report['finalDirectories700'] and report['finalRegularFiles600'] and report['temporaryDirectoryRemoved']
    except Exception:
        report['completed']=False;report['exceptionOccurred']=True
    finally:os.umask(oldmask)
    # Refuse a late concurrent collision as well as the preflight existence check.
    with args.result.open('x') as output:output.write(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'completed':report['completed'],'testExit':report.get('testExit'),'caseCodes':report.get('wire',{}).get('completedCases',[]),
                      'encryptedClientFrames':report.get('wire',{}).get('encryptedClientFrames'),'encryptedServerFrames':report.get('wire',{}).get('encryptedServerFrames'),
                      'plaintextReadRequests':report.get('wire',{}).get('plaintextReadRequests')}))
    return 0 if report['completed'] else 1

if __name__=='__main__':raise SystemExit(main())
