"""Gera os efeitos sonoros do jogo por síntese (sem precisar de nenhum arquivo de fora).

Uso:  py ferramentas/gerar_sons.py
Precisa de:  pip install numpy scipy   e do ffmpeg (para gravar .ogg)

Cria:
  sons/MasmorraSons.ogg      todos os sons num arquivo só (envie este para o Roblox)
  sons/individuais/*.ogg     cada som separado (se preferir enviar um por um)
  src/client/SonsMapa.luau   onde cada som começa e termina dentro do arquivo único

Depois de enviar o MasmorraSons.ogg para o Roblox, cole o ID em src/shared/Config.luau
(Config.SONS_ID). Veja COMO_USAR.md.
"""

import os
import shutil
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

TAXA = 44100
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PASTA_SONS = os.path.join(RAIZ, "sons")
MAPA_LUAU = os.path.join(RAIZ, "src", "client", "SonsMapa.luau")
INTERVALO = 0.25  # silêncio entre um som e outro no arquivo único

rng = np.random.default_rng(7)


# ---------------------------------------------------------------------------
# Blocos básicos
# ---------------------------------------------------------------------------

def tempo(d):
    return np.arange(int(d * TAXA)) / TAXA


def ruido(d):
    return rng.standard_normal(int(d * TAXA))


def ruido_marrom(d):
    r = passa_alta(np.cumsum(ruido(d)), 25, 2)  # ruído grave, sem o desvio lento
    return r / (np.max(np.abs(r)) + 1e-9)


def passa_baixa(x, f, ordem=4):
    return signal.sosfilt(signal.butter(ordem, min(f, TAXA / 2 - 100), "low", fs=TAXA, output="sos"), x)


def passa_alta(x, f, ordem=4):
    return signal.sosfilt(signal.butter(ordem, f, "high", fs=TAXA, output="sos"), x)


def passa_banda(x, lo, hi, ordem=3):
    return signal.sosfilt(signal.butter(ordem, [lo, min(hi, TAXA / 2 - 100)], "band", fs=TAXA, output="sos"), x)


def filtro_movel(x, freqs, q=4.0, bloco=256):
    """Passa-banda ressonante cujo centro segue a curva 'freqs' (uma por amostra)."""
    saida = np.zeros_like(x)
    zi = np.zeros(2)
    for i in range(0, len(x), bloco):
        f = float(np.clip(freqs[min(i + bloco // 2, len(freqs) - 1)], 40, TAXA / 2 - 200))
        b, a = signal.iirpeak(f, q, fs=TAXA)
        saida[i:i + bloco], zi = signal.lfilter(b, a, x[i:i + bloco], zi=zi)
    return saida


def curva(d, pontos):
    """Curva linear por pontos [(t0, v0), (t1, v1)...] com 'd' segundos."""
    t = tempo(d)
    ts, vs = zip(*pontos)
    return np.interp(t, ts, vs)


def envelope(d, ataque=0.005, queda=0.3, sustain_ate=None):
    t = tempo(d)
    e = np.minimum(1, t / max(ataque, 1e-4))
    inicio_queda = sustain_ate if sustain_ate is not None else ataque
    e *= np.where(t < inicio_queda, 1, np.exp(-(t - inicio_queda) / max(queda, 1e-4)))
    return e


def seno(freqs, d=None):
    """Seno com frequência variável (array) ou fixa (número, com duração d)."""
    if np.isscalar(freqs):
        freqs = np.full(int(d * TAXA), float(freqs))
    fase = 2 * np.pi * np.cumsum(freqs) / TAXA
    return np.sin(fase)


def fm(portadora, razao, indice, d, queda_indice=0.2):
    t = tempo(d)
    mod = np.sin(2 * np.pi * portadora * razao * t) * indice * np.exp(-t / queda_indice)
    return np.sin(2 * np.pi * portadora * t + mod)


def sino(freqs, d, queda=0.4):
    t = tempo(d)
    x = np.zeros(len(t))
    for i, f in enumerate(freqs):
        x += np.sin(2 * np.pi * f * t) * np.exp(-t / (queda / (1 + i * 0.4))) / (1 + i * 0.5)
    return x


def corda(freq, d, brilho=0.5):
    """Corda dedilhada (Karplus-Strong)."""
    n = int(d * TAXA)
    periodo = int(TAXA / freq)
    buffer = rng.uniform(-1, 1, periodo)
    saida = np.zeros(n)
    for i in range(n):
        saida[i] = buffer[i % periodo]
        buffer[i % periodo] = 0.5 * (buffer[i % periodo] + buffer[(i + 1) % periodo]) * (0.994 + 0.005 * brilho)
    return saida


def saturar(x, k=2.0):
    return np.tanh(k * x) / np.tanh(k)


def eco(x, tamanho=0.6, mistura=0.25):
    """Reverberação simples: convolução com ruído que decai."""
    ir = ruido(tamanho) * np.exp(-tempo(tamanho) / (tamanho / 5))
    ir = passa_baixa(ir, 5000)
    molhado = signal.fftconvolve(x, ir)[: len(x) + int(tamanho * TAXA)]
    seco = np.concatenate([x, np.zeros(len(molhado) - len(x))])
    molhado /= np.max(np.abs(molhado)) + 1e-9
    return seco * (1 - mistura) + molhado * mistura * np.max(np.abs(x))


def juntar(*partes):
    n = max(len(p) for p in partes)
    saida = np.zeros(n)
    for p in partes:
        saida[: len(p)] += p
    return saida


def atraso(x, segundos):
    return np.concatenate([np.zeros(int(segundos * TAXA)), x])


def normalizar(x, pico=0.9):
    x = x - np.mean(x)
    m = np.max(np.abs(x))
    return x / m * pico if m > 0 else x


def suavizar_bordas(x, entrada=0.003, saida=0.02):
    n_in, n_out = int(entrada * TAXA), int(saida * TAXA)
    x = x.copy()
    if n_in:
        x[:n_in] *= np.linspace(0, 1, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


# ---------------------------------------------------------------------------
# Sons
# ---------------------------------------------------------------------------

def vento(d, f_ini, f_meio, f_fim, q=2.5, ataque=0.35):
    """Vulto rápido: ruído com um filtro que sobe e desce (o "fuuu" de uma lâmina)."""
    freqs = curva(d, [(0, f_ini), (d * ataque, f_meio), (d, f_fim)])
    x = filtro_movel(ruido(d), freqs, q)
    env = curva(d, [(0, 0), (d * ataque, 1), (d, 0)]) ** 1.5
    return x * env


def som_espada():
    d = 0.32
    corpo = vento(d, 500, 2600, 700, q=3, ataque=0.4)
    # "shing" curto da lâmina no meio do golpe
    brilho = (seno(3300, 0.15) + 0.6 * seno(4870, 0.15)) * envelope(0.15, 0.01, 0.035) * 0.15
    return juntar(corpo, atraso(brilho, 0.11))


def som_espada_pesada():
    d = 0.45
    corpo = vento(d, 300, 1600, 350, q=2.2, ataque=0.45)
    grave = passa_baixa(ruido(d), 400) * curva(d, [(0, 0), (0.2, 1), (d, 0)]) * 0.8
    return juntar(corpo, grave)


def som_adaga():
    return vento(0.18, 1400, 4500, 1600, q=3.5, ataque=0.35)


def som_impacto():
    d = 0.22
    t = tempo(d)
    baque = seno(curva(d, [(0, 140), (0.08, 60), (d, 45)])) * np.exp(-t / 0.07)
    estalo = passa_baixa(ruido(d), 1800) * np.exp(-t / 0.025)
    return saturar(juntar(baque * 1.2, estalo * 0.8), 2.5)


def som_critico():
    d = 0.5
    t = tempo(d)
    metal = fm(1250, 1.41, 4, d, 0.08) * np.exp(-t / 0.18) * 0.5
    return juntar(som_impacto() * 1.2, metal, sino([2500, 3740], d, 0.15) * 0.3)


def som_escudo():
    d = 0.7
    t = tempo(d)
    clang = fm(520, 1.41, 6, d, 0.06) * np.exp(-t / 0.25)
    clang += fm(780, 2.76, 3, d, 0.05) * np.exp(-t / 0.18) * 0.5
    clique = passa_alta(ruido(d), 2000) * np.exp(-t / 0.01)
    return eco(juntar(clang, clique * 0.6), 0.4, 0.2)


def som_escudo_perfeito():
    d = 1.2
    brilho = sino([1400, 2100, 2800, 4200], d, 0.6)
    return eco(juntar(som_escudo() * 0.9, brilho * 0.7), 0.6, 0.3)


def som_giro():
    d = 2.0
    t = tempo(d)
    rotacao = 0.5 + 0.5 * np.sin(2 * np.pi * 7 * t) ** 2
    freqs = 900 + 700 * np.sin(2 * np.pi * 7 * t)
    x = filtro_movel(ruido(d), freqs, 2.5) * rotacao
    x *= curva(d, [(0, 0), (0.15, 1), (d - 0.3, 1), (d, 0)])
    return x


def som_julgamento():
    d = 2.4
    t = tempo(d)
    subida = vento(0.35, 300, 3000, 2500, q=1.5, ataque=0.95)
    boom_t = tempo(d - 0.33)
    boom = seno(curva(d - 0.33, [(0, 70), (0.4, 35), (d - 0.33, 30)])) * np.exp(-boom_t / 0.5)
    estrondo = passa_baixa(ruido(d - 0.33), 900) * np.exp(-boom_t / 0.35)
    coro = sum(seno(f, d - 0.33) for f in (440, 554, 659, 880)) * np.exp(-boom_t / 0.9) * (0.6 + 0.4 * np.sin(2 * np.pi * 5 * boom_t))
    impacto = saturar(juntar(boom * 1.4, estrondo), 2)
    return eco(juntar(subida * 0.6, atraso(juntar(impacto, coro * 0.12), 0.33)), 0.9, 0.3)


def som_arco_puxar():
    d = 0.3
    t = tempo(d)
    rangido = passa_banda(ruido(d), 300, 1400) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * curva(d, [(0, 30), (d, 70)]) * t)))
    return rangido * curva(d, [(0, 0), (0.05, 0.6), (d, 1)]) * 0.5


def som_arco_soltar():
    d = 0.45
    t = tempo(d)
    corda_ = corda(110, d) * np.exp(-t / 0.15)
    zunido = vento(0.25, 1200, 3500, 1500, q=3, ataque=0.2) * 0.7
    estalo = passa_alta(ruido(d), 1500) * np.exp(-t / 0.008)
    return juntar(corda_, zunido, estalo * 0.5)


def som_flecha_impacto():
    d = 0.18
    t = tempo(d)
    madeira = filtro_movel(ruido(d), np.full(len(t), 750), 12) * np.exp(-t / 0.04)
    baque = seno(curva(d, [(0, 160), (d, 70)])) * np.exp(-t / 0.05)
    return juntar(madeira * 1.5, baque * 0.6)


def som_chuva_flechas():
    d = 2.8
    saida = np.zeros(int(d * TAXA))
    for _ in range(26):
        inicio = rng.uniform(0, d - 0.35)
        dd = 0.3
        tt = tempo(dd)
        apito = seno(curva(dd, [(0, rng.uniform(1800, 2600)), (dd, rng.uniform(700, 1000))])) * np.sin(np.pi * tt / dd) * 0.25
        pedaco = juntar(apito, atraso(som_flecha_impacto() * 0.5, dd * 0.9))
        i = int(inicio * TAXA)
        n = min(len(pedaco), len(saida) - i)
        saida[i:i + n] += pedaco[:n]
    return saida


def som_dardo_arcano():
    d = 0.35
    t = tempo(d)
    zap = seno(curva(d, [(0, 1600), (d, 420)]) + 300 * np.sin(2 * np.pi * 45 * t)) * np.exp(-t / 0.12)
    brilho = passa_alta(ruido(d), 4000) * np.exp(-t / 0.05) * 0.3
    return juntar(zap, brilho)


def som_lanca_gelo():
    d = 0.45
    t = tempo(d)
    cristal = sino([2600, 3900, 5100, 6200], d, 0.25)
    sopro = passa_banda(ruido(d), 2500, 9000) * curva(d, [(0, 0), (0.05, 1), (d, 0)]) * 0.4
    return juntar(cristal * 0.7, sopro)


def som_gelo_quebra():
    d = 0.5
    saida = passa_alta(ruido(d), 3000) * np.exp(-tempo(d) / 0.05) * 0.5
    for _ in range(9):
        inicio = rng.uniform(0, 0.12)
        p = sino([rng.uniform(2500, 7000)], 0.3, 0.06)
        saida = juntar(saida, atraso(p * 0.4, inicio))
    return saida


def som_bola_fogo():
    d = 0.7
    t = tempo(d)
    rugido = passa_baixa(ruido_marrom(d), 500) * curva(d, [(0, 0), (0.1, 1), (d, 0)])
    sopro = vento(d, 300, 1100, 400, q=1.5, ataque=0.25) * 0.6
    estalos = (rng.random(len(t)) > 0.9985) * rng.uniform(-1, 1, len(t))
    estalos = passa_alta(estalos, 1500) * curva(d, [(0, 1), (d, 0.2)])
    return juntar(rugido * 1.2, sopro, estalos * 2)


def som_explosao():
    d = 1.3
    t = tempo(d)
    corpo = filtro_movel(ruido(d), curva(d, [(0, 2500), (0.15, 600), (d, 120)]), 0.8) * np.exp(-t / 0.3)
    sub = seno(curva(d, [(0, 90), (0.3, 40), (d, 30)])) * np.exp(-t / 0.4)
    return eco(saturar(juntar(corpo * 1.3, sub * 1.4), 3), 0.7, 0.2)


def som_carregar():
    d = 1.1
    t = tempo(d)
    tom = seno(curva(d, [(0, 160), (d, 420)])) * (0.6 + 0.4 * np.sin(2 * np.pi * curva(d, [(0, 6), (d, 18)]) * t))
    ar = filtro_movel(ruido(d), curva(d, [(0, 400), (d, 3000)]), 3) * 0.5
    return juntar(tom * 0.5, ar) * curva(d, [(0, 0), (d * 0.9, 1), (d, 0.6)])


def som_carga_cheia():
    return eco(sino([1320, 1980, 2640], 0.8, 0.35), 0.4, 0.2)


def som_vazio_explode():
    implosao = vento(0.3, 3000, 400, 120, q=1.5, ataque=0.95)
    boom = som_explosao()
    t = tempo(len(boom) / TAXA)
    fase = boom * (0.7 + 0.3 * np.sin(2 * np.pi * 3 * t))
    grave = seno(curva(1.0, [(0, 55), (1.0, 28)])) * np.exp(-tempo(1.0) / 0.5)
    return juntar(implosao * 0.8, atraso(juntar(fase, grave), 0.28))


def som_meteoro():
    d = 0.9
    t = tempo(d)
    apito = seno(curva(d, [(0, 1700), (d, 260)])) * curva(d, [(0, 0.2), (d, 1)]) * 0.4
    rugido = passa_baixa(ruido_marrom(d), 700) * curva(d, [(0, 0.2), (d, 1)])
    return juntar(apito, rugido)


def som_raio():
    d = 1.4
    t = tempo(d)
    estalo = passa_alta(ruido(d), 1500) * np.exp(-t / 0.04) * 1.2
    trovao = passa_baixa(ruido_marrom(d), 220) * np.exp(-t / 0.5) * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * t))
    return saturar(juntar(estalo, trovao * 1.6), 2)


def som_tempestade():
    d = 3.0
    t = tempo(d)
    rumor = passa_baixa(ruido_marrom(d), 160) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.9 * t))
    return rumor * curva(d, [(0, 0), (0.6, 1), (d - 0.8, 1), (d, 0)])


def som_sem_mana():
    d = 0.35
    t = tempo(d)
    chiado = filtro_movel(ruido(d), curva(d, [(0, 3000), (d, 400)]), 2) * np.exp(-t / 0.12)
    blip = seno(curva(d, [(0, 300), (d, 150)])) * np.exp(-t / 0.08) * 0.6
    return juntar(chiado, blip)


def som_passo_sombrio():
    d = 0.5
    sombra = vento(d, 200, 1400, 150, q=1.8, ataque=0.8)
    sub = seno(curva(d, [(0, 120), (d, 40)])) * curva(d, [(0, 0), (0.35, 1), (d, 0)]) * 0.8
    return eco(juntar(sombra, sub), 0.5, 0.25)


def som_investida():
    return vento(0.3, 600, 3200, 900, q=2, ataque=0.25) * 1.2


def som_esquiva():
    return vento(0.25, 500, 1900, 600, q=2, ataque=0.3) * 0.8


def som_sangue():
    d = 0.22
    t = tempo(d)
    molhado = filtro_movel(ruido(d), 500 + 400 * np.sin(2 * np.pi * 28 * t), 5) * np.exp(-t / 0.06)
    estalo = passa_baixa(ruido(d), 2500) * np.exp(-t / 0.01)
    return juntar(molhado * 1.4, estalo * 0.4)


def som_supremo():
    d = 1.1
    t = tempo(d)
    acorde = sum(seno(curva(d, [(0, f * 0.5), (d * 0.7, f)]), None) for f in (330, 415, 494, 660)) * curva(d, [(0, 0), (0.7, 1), (d, 0)])
    ar = filtro_movel(ruido(d), curva(d, [(0, 300), (0.8, 5000), (d, 4000)]), 2) * curva(d, [(0, 0), (0.8, 1), (d, 0)])
    return eco(juntar(acorde * 0.25, ar * 0.6), 0.6, 0.3)


def som_inimigo_morre():
    d = 0.45
    t = tempo(d)
    puf = passa_baixa(ruido(d), 1200) * np.exp(-t / 0.1)
    queda = seno(curva(d, [(0, 500), (d, 120)])) * np.exp(-t / 0.15) * 0.5
    return juntar(puf, queda)


def som_dano_jogador():
    d = 0.25
    t = tempo(d)
    baque = seno(curva(d, [(0, 110), (d, 55)])) * np.exp(-t / 0.08)
    crunch = passa_banda(ruido(d), 400, 2500) * np.exp(-t / 0.04) * 0.6
    return saturar(juntar(baque, crunch), 3)


def som_moeda():
    d = 0.35
    a = sino([1568, 3136], 0.12, 0.05)
    b = sino([2093, 4186], d - 0.07, 0.15)
    return juntar(a * 0.7, atraso(b, 0.07))


def som_carta():
    d = 0.2
    t = tempo(d)
    folha = passa_alta(ruido(d), 2500) * curva(d, [(0, 0), (0.03, 1), (d, 0)]) * 0.6
    clique = passa_alta(ruido(d), 4000) * np.exp(-t / 0.005)
    return juntar(folha, clique)


def som_clique():
    d = 0.06
    return sino([1800, 3600], d, 0.015)


def som_reviver():
    notas = [523, 659, 784, 1047]
    saida = np.zeros(1)
    for i, f in enumerate(notas):
        saida = juntar(saida, atraso(sino([f, f * 2], 0.7, 0.25), i * 0.09))
    return eco(saida, 0.5, 0.3)


def som_caiu():
    d = 0.9
    t = tempo(d)
    return eco(seno(curva(d, [(0, 440), (d, 180)])) * np.exp(-t / 0.35) * (0.8 + 0.2 * np.sin(2 * np.pi * 6 * t)), 0.5, 0.25)


def som_portal():
    d = 1.0
    t = tempo(d)
    x = filtro_movel(ruido(d), 900 + 600 * np.sin(2 * np.pi * 3 * t), 3)
    tom = seno(curva(d, [(0, 200), (d, 600)])) * 0.3
    return eco(juntar(x, tom) * curva(d, [(0, 0), (0.3, 1), (d, 0)]), 0.5, 0.3)


SONS = {
    # ataques
    "espada": som_espada,
    "espadaPesada": som_espada_pesada,
    "adaga": som_adaga,
    "impacto": som_impacto,
    "critico": som_critico,
    "sangue": som_sangue,
    # cavaleiro
    "escudo": som_escudo,
    "escudoPerfeito": som_escudo_perfeito,
    "giro": som_giro,
    "julgamento": som_julgamento,
    # arqueiro
    "arcoPuxar": som_arco_puxar,
    "arcoSoltar": som_arco_soltar,
    "flechaImpacto": som_flecha_impacto,
    "chuvaFlechas": som_chuva_flechas,
    # mago
    "dardoArcano": som_dardo_arcano,
    "lancaGelo": som_lanca_gelo,
    "geloQuebra": som_gelo_quebra,
    "bolaFogo": som_bola_fogo,
    "explosao": som_explosao,
    "vazioExplode": som_vazio_explode,
    "meteoro": som_meteoro,
    "raio": som_raio,
    "tempestade": som_tempestade,
    "semMana": som_sem_mana,
    # assassino
    "passoSombrio": som_passo_sombrio,
    "investida": som_investida,
    # gerais
    "carregar": som_carregar,
    "cargaCheia": som_carga_cheia,
    "esquiva": som_esquiva,
    "supremo": som_supremo,
    "inimigoMorre": som_inimigo_morre,
    "danoJogador": som_dano_jogador,
    "moeda": som_moeda,
    "carta": som_carta,
    "clique": som_clique,
    "reviver": som_reviver,
    "caiu": som_caiu,
    "portal": som_portal,
}


# ---------------------------------------------------------------------------
# Gravação
# ---------------------------------------------------------------------------

def gravar_wav(caminho, x):
    dados = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(caminho, "wb") as arquivo:
        arquivo.setnchannels(1)
        arquivo.setsampwidth(2)
        arquivo.setframerate(TAXA)
        arquivo.writeframes(dados.tobytes())


def gravar_ogg(caminho, x):
    with tempfile.TemporaryDirectory() as pasta:
        wav = os.path.join(pasta, "som.wav")
        gravar_wav(wav, x)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", caminho], check=True)


def main():
    if not shutil.which("ffmpeg"):
        raise SystemExit("Preciso do ffmpeg instalado para gravar os .ogg")
    individuais = os.path.join(PASTA_SONS, "individuais")
    os.makedirs(individuais, exist_ok=True)

    partes, mapa, posicao = [], [], 0.0
    for nome, funcao in SONS.items():
        x = suavizar_bordas(normalizar(funcao()))
        duracao = len(x) / TAXA
        gravar_ogg(os.path.join(individuais, nome + ".ogg"), x)
        mapa.append((nome, posicao, duracao))
        partes.append(x)
        partes.append(np.zeros(int(INTERVALO * TAXA)))
        posicao += duracao + INTERVALO
        print(f"  {nome:16s} {duracao:5.2f}s")

    tudo = np.concatenate(partes)
    gravar_ogg(os.path.join(PASTA_SONS, "MasmorraSons.ogg"), tudo)

    linhas = [
        "-- ARQUIVO GERADO por ferramentas/gerar_sons.py (não edite à mão: rode o script de novo).",
        "-- Onde cada som começa e quanto dura dentro de sons/MasmorraSons.ogg (em segundos).",
        "",
        "return {",
    ]
    for nome, inicio, duracao in mapa:
        linhas.append(f"\t{nome} = {{ {inicio:.4f}, {duracao:.4f} }},")
    linhas.append("}")
    with open(MAPA_LUAU, "w", encoding="utf-8", newline="\n") as arquivo:
        arquivo.write("\n".join(linhas) + "\n")
    print(f"\n{len(mapa)} sons, {len(tudo) / TAXA:.1f}s no total -> sons/MasmorraSons.ogg")


if __name__ == "__main__":
    main()
