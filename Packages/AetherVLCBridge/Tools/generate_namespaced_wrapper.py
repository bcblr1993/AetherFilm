#!/usr/bin/env python3
"""Generate an isolated, namespaced fixed official wrapper; never edit upstream."""
from pathlib import Path
import argparse,re,shutil,json,hashlib
parser=argparse.ArgumentParser()
parser.add_argument('--upstream',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args();upstream=args.upstream.resolve();probe=args.output.resolve()
probe.mkdir(exist_ok=True);inc=probe/'include';inc.mkdir(exist_ok=True);src=probe/'src';src.mkdir(exist_ok=True)
header=(upstream/'Headers/Public/Playback/VLCMediaPlayer.h').read_text()
names=['VLCMediaPlayer','VLCMediaPlayerDelegate','VLCMediaPlayerStateToString']+re.findall(r'FOUNDATION_EXPORT NSNotificationName const (\w+)',header)
header=re.sub(r'typedef NS_ENUM\([^;{]+\);','',header)
header=re.sub(r'typedef NS_ENUM\([^;{]+\)\s*\{[^}]+\}[^;]*;','',header,flags=re.S)
header=header.replace('#import <Foundation/Foundation.h>','#import <Foundation/Foundation.h>\n#import <VLCKit/VLCMediaPlayer.h>')
def namespace(text):
    for name in sorted(names,key=len,reverse=True):
        text=re.sub(r'\b'+re.escape(name)+r'\b','Aether'+name,text)
    return text
header=namespace(header).replace('#import <VLCKit/AetherVLCMediaPlayer.h>','#import <VLCKit/VLCMediaPlayer.h>')
header=header.replace('@protocol AetherVLCMediaPlayerDelegate <NSObject>','''typedef NS_ENUM(NSInteger, AetherVLCMediaStoppingReason) {
    AetherVLCMediaStoppingReasonError = 0,
    AetherVLCMediaStoppingReasonEndOfStream = 1,
    AetherVLCMediaStoppingReasonUser = 2,
};

@protocol AetherVLCMediaPlayerDelegate <NSObject>''')
header=header.replace('@optional\n','@optional\n- (void)mediaPlayerStoppingWithReason:(AetherVLCMediaStoppingReason)reason;\n',1)
(inc/'AetherVLCMediaPlayer.h').write_text(header)
implementation=namespace((upstream/'Sources/Playback/VLCMediaPlayer.m').read_text()).replace('#import <VLCMediaPlayer.h>','#import <AetherVLCMediaPlayer.h>').replace('#import <VLCMediaPlayer+Internal.h>','#import <AetherVLCMediaPlayer+Internal.h>')
implementation=implementation.replace('[VLCAdjustFilter createWithVLCMediaPlayer:self]','[VLCAdjustFilter createWithVLCMediaPlayer:(id)self]')
callback='''static void AetherHandleMediaStopping(void *opaque, libvlc_media_t *media,
                                     libvlc_stopping_reason_t reason)
{
    (void)media;
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id object) {
            AetherVLCMediaPlayer *player = object;
            if ([player.delegate respondsToSelector:@selector(mediaPlayerStoppingWithReason:)])
                [player.delegate mediaPlayerStoppingWithReason:(AetherVLCMediaStoppingReason)reason];
        }];
    }
}

'''
anchor='static const struct libvlc_media_player_cbs VLCMediaPlayerCallbacks = {'
implementation=implementation.replace(anchor,callback+anchor+'\n    .on_media_stopping = AetherHandleMediaStopping,')
(src/'AetherVLCMediaPlayer.m').write_text(implementation)
for path in (upstream/'Headers/Internal').glob('*.h'):
    text=path.read_text()
    if path.name in ['VLCLibVLCBridging.h','VLCMediaPlayer+Internal.h']:
        text=namespace(text).replace('#import <VLCMediaPlayer.h>','#import <AetherVLCMediaPlayer.h>')
    name='AetherVLCMediaPlayer+Internal.h' if path.name=='VLCMediaPlayer+Internal.h' else path.name
    (inc/name).write_text(text)
for path in (upstream/'Headers/Internal').glob('*.pch'):shutil.copy2(path,inc/path.name)
shutil.copy2(upstream/'COPYING',probe/'VLCKit-LICENSE.txt')
record={'fixedWrapperRevision':'8f5ce02f09a7da5d061a24ddac3cb432f2a9b332','namespaceSymbols':names,'sourceSHA256':hashlib.sha256(implementation.encode()).hexdigest(),'headerSHA256':hashlib.sha256(header.encode()).hexdigest(),'engineChanged':False,'productionProjectChanged':False}
(probe/'generation.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record))
