import wave
import numpy as np

rate = 44100
rng = np.random.default_rng(7)
out = 'assets/sfx/'


def save(name, signal):
    signal = signal / max(1e-9, np.abs(signal).max()) * 0.8
    data = (signal * 32767).astype(np.int16)
    with wave.open(out + name, 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(data.tobytes())


def lowpass(signal, cutoff):
    a = np.exp(-2 * np.pi * cutoff / rate)
    y = np.zeros_like(signal)
    acc = 0.0
    for i, v in enumerate(signal):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def loopable(signal, fade):
    head = signal[:fade]
    body = signal[fade:].copy()
    ramp = np.linspace(0, 1, fade)
    body[-fade:] = body[-fade:] * (1 - ramp) + head * ramp
    return body


def seconds(s):
    return np.arange(int(rate * s)) / rate


t = seconds(2.2)
rumble = lowpass(rng.standard_normal(t.size), 500) + 0.35 * lowpass(rng.standard_normal(t.size), 2500)
rumble += 0.15 * np.sin(2 * np.pi * 70 * t)
save('thrust.wav', loopable(rumble, 4000))

t = seconds(1.6)
hiss = rng.standard_normal(t.size) - lowpass(rng.standard_normal(t.size), 1500)
hiss = lowpass(hiss, 6000)
save('side_jet.wav', loopable(hiss, 3000))

t = seconds(0.75)
noise = rng.standard_normal(t.size)
whoosh = np.zeros_like(t)
for i, f in enumerate(np.linspace(400, 3500, 6)):
    whoosh += lowpass(noise, f) * np.exp(-((t - 0.35 - i * 0.02) ** 2) / 0.02)
save('flip.wav', whoosh * np.sin(np.pi * t / t[-1]))

t = seconds(0.35)
thud = np.sin(2 * np.pi * (90 - 50 * t) * t) * np.exp(-t * 14) + 0.3 * lowpass(rng.standard_normal(t.size), 800) * np.exp(-t * 25)
save('land.wav', thud)

t = seconds(1.4)
crash = lowpass(rng.standard_normal(t.size), 3000) * np.exp(-t * 3.2)
crash += 0.8 * np.sin(2 * np.pi * (60 - 20 * t) * t) * np.exp(-t * 5)
metal = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in [(523, 6), (811, 8), (1307, 9), (1960, 12)])
save('crash.wav', crash + 0.25 * metal)

t = seconds(0.45)
notes = np.where(t < 0.12, 880, np.where(t < 0.24, 1175, 1568))
chime = np.sin(2 * np.pi * notes * t) * np.exp(-(t % 0.12) * 10) * np.exp(-t * 3)
save('bonus.wav', chime)
