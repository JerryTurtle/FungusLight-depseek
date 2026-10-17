"""Deterministic original synthesis; no downloaded samples or external dependencies."""
import math
import random
import struct
import wave
from pathlib import Path

destination = Path(__file__).resolve().parents[1] / 'game/assets/audio'
destination.mkdir(exist_ok=True)
rate = 44100
for index, (name, duration) in enumerate([('swing', .18), ('hit', .16), ('cast', .46), ('hurt', .25), ('shell_break', .34), ('shield_hit', .24), ('rain_impact', .5)]):
    rng = random.Random(1200 + index)
    samples = []
    low_noise = 0
    for i in range(int(rate * duration)):
        t = i / rate
        u = t / duration
        attack = min(1, t / .006)
        noise = rng.uniform(-1, 1)
        low_noise = .72 * low_noise + .28 * noise
        if name == 'swing':
            value = (.75 * low_noise + .18 * math.sin(2*math.pi*(750*t-1300*t*t))) * math.sin(math.pi*u)**1.6
        elif name == 'hit':
            value = (.5 * math.sin(2*math.pi*(160*t-220*t*t)) + .45*noise*math.exp(-65*t)) * math.exp(-28*t)
        elif name == 'cast':
            value = sum(math.sin(2*math.pi*f*t)*math.exp(-k*t) for f,k in [(660,7),(990,9),(1320,13)]) / 3 * (1-u)
        elif name == 'shell_break':
            value = (.4*math.sin(2*math.pi*85*t)+.6*noise*math.exp(-12*t))*math.exp(-10*t)
        elif name == 'shield_hit':
            value = (.5*math.sin(2*math.pi*820*t)+.25*math.sin(2*math.pi*1230*t))*math.exp(-18*t)
        elif name == 'rain_impact':
            value = (.3*math.sin(2*math.pi*110*t)+.45*low_noise+.2*math.sin(2*math.pi*1760*t)*math.exp(-10*t))*math.exp(-7*t)
        else:
            value = (.65*math.sin(2*math.pi*(210*t-250*t*t))+.25*low_noise)*math.exp(-15*t)
        samples.append(int(max(-1,min(1,value*attack*.5))*32767))
    with wave.open(str(destination / f'{name}.wav'),'wb') as audio:
        audio.setparams((1,2,rate,len(samples),'NONE','not compressed'))
        audio.writeframes(struct.pack('<'+'h'*len(samples),*samples))
    print(name, len(samples), 'samples', 'peak', max(abs(v) for v in samples))
