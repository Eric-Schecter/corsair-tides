"""Original 16-bar island loop: plucked chords, marimba, bass and soft shaker."""
from pathlib import Path
import math, random, wave
from array import array
RATE=22050
BEAT=60/96
LENGTH=16*4*BEAT
frames=round(LENGTH*RATE)
mix=array('f',[0])*(frames*2)
rng=random.Random(716)
def note(midi,beat,duration,gain,voice,pan=0):
    n=int(duration*RATE);freq=440*2**((midi-69)/12)
    start=int(beat*BEAT*RATE)
    left=math.sqrt((1-pan)/2);right=math.sqrt((1+pan)/2)
    previous=0
    for i in range(n):
        t=i/RATE;phase=2*math.pi*freq*t
        if voice=='pluck':
            sig=sum(math.sin(phase*k)*math.exp(-t*(4+k*1.5))/(k*k) for k in range(1,5))
        elif voice=='bell':
            sig=math.sin(phase)*math.exp(-t*4)+.18*math.sin(phase*2.01)*math.exp(-t*8)
        elif voice=='bass':sig=(math.sin(phase)+.12*math.sin(phase*2))*math.exp(-t*2.7)
        else:
            noise=rng.uniform(-1,1);sig=(noise-previous)*.2*math.exp(-t*38);previous=noise
        sig*=min(1,t/.008)*min(1,(duration-t)/.04)*gain
        index=((start+i)%frames)*2
        mix[index]+=sig*left;mix[index+1]+=sig*right
chords=[[60,64,67,71],[57,60,64,67],[53,57,60,64],[55,59,62,67]]
melodies=[[76,79,81,79,76,74],[72,76,79,76,74,72],[72,74,76,79,76,72],[74,76,74,71,67,71],
          [76,79,84,81,79,76],[79,76,74,72,69,72],[72,76,79,81,79,76],[74,71,69,67,71,74]]
for bar in range(16):
    chord=chords[bar%4]; start=bar*4
    for off in [0,1.5,2.5,3.5]:
        for j,pitch in enumerate(chord):note(pitch,start+off+j*.025,.7,.095,'pluck',-.35)
    for off,pitch in [(0,chord[0]-24),(2,chord[0]-12)]:note(pitch,start+off,.9,.17,'bass')
    for off,pitch in zip([0,.75,1.5,2.5,3,3.5],melodies[bar%8]):
        if bar in [7,15] and off>2.5:continue
        note(pitch,start+off,.75,.12 if bar<8 else .105,'bell',.25)
    for off in [i*.5 for i in range(8)]:note(60,start+off,.12,.055 if off%1 else .035,'shaker',.15)
# Wrapped note tails make a seamless bar boundary, with no fade to silence.
mix=array('f',(math.tanh(x*1.3) for x in mix))
scale=.65/max(abs(x) for x in mix)
out=Path(__file__).resolve().parents[1]/'assets/audio/harbor-bgm.wav'
with wave.open(str(out),'wb') as f:
    f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE)
    pcm=array('h',(int(x*scale*32767) for x in mix))
    import sys
    if sys.byteorder!='little':pcm.byteswap()
    f.writeframes(pcm.tobytes())
print(f'{out}: {LENGTH:.1f}s seamless loop, peak 0.65')
