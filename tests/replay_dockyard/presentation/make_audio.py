#!/usr/bin/env python3
"""Deterministic original Dockyard synthesis; stdlib only, no downloaded samples."""
import math
from pathlib import Path
import random
import struct
import wave

ROOT=Path(__file__).resolve().parents[3]
RATE=44100

def render(name,seconds,sample):
    path=ROOT/'examples/replay_dockyard/audio'/name
    path.parent.mkdir(parents=True,exist_ok=True)
    rng=random.Random(0xD0C4)
    values=[sample(i/RATE,rng) for i in range(round(seconds*RATE))]
    peak=max(max(abs(v) for v in values),1)
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h',round(max(-1,min(1,v/peak*.72))*32767)) for v in values))
    print(path.relative_to(ROOT))

def boost(t,rng):
    envelope=min(1,t/.006)*math.exp(-t*19)
    return envelope*(.42*math.sin(2*math.pi*(230*t-170*t*t))+.22*rng.uniform(-1,1))

def latch(t,rng):
    thud=min(1,t/.002)*math.exp(-t*48)*(.5*rng.uniform(-1,1)+.6*math.sin(2*math.pi*115*t))
    bell=0
    for start,freq in [(.09,523.251),(.15,659.255),(.21,783.991)]:
        x=t-start
        if x>=0:bell+=.22*min(1,x/.004)*math.exp(-x*9)*math.sin(2*math.pi*freq*x)
    return thud+bell

if __name__=='__main__':
    render('boost.wav',.25,boost)
    render('latch_score.wav',.72,latch)
