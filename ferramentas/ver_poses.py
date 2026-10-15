"""Desenha as poses de uma classe (R15 com arma e escudo) em imagens PNG, fora do Roblox.

Serve para conferir as animações de Poses.luau sem abrir o Studio: o personagem é montado
com as mesmas juntas do R15 e as poses são misturadas como em Client/Animacoes.luau
(postura + pose parada + golpe).

Uso:
    py ferramentas/ver_poses.py --luau CAMINHO/luau.exe --classe cavaleiro --acao ataque1 --saida poses.png
    (sem --acao, desenha a postura parada)

Precisa de numpy e Pillow (pip install numpy pillow) e do luau.exe
(https://github.com/luau-lang/luau/releases).
"""

import argparse
import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------------------
# Matemática de CFrame (matriz 4x4: rotação + posição)
# ---------------------------------------------------------------------------


def cf(x=0.0, y=0.0, z=0.0):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    return m


def rx(a):
    c, s = math.cos(a), math.sin(a)
    m = np.eye(4)
    m[1, 1], m[1, 2], m[2, 1], m[2, 2] = c, -s, s, c
    return m


def ry(a):
    c, s = math.cos(a), math.sin(a)
    m = np.eye(4)
    m[0, 0], m[0, 2], m[2, 0], m[2, 2] = c, s, -s, c
    return m


def rz(a):
    c, s = math.cos(a), math.sin(a)
    m = np.eye(4)
    m[0, 0], m[0, 1], m[1, 0], m[1, 1] = c, -s, s, c
    return m


def euler_yxz(a, b, c):
    """CFrame.fromEulerAnglesYXZ(rx, ry, rz) = Ry * Rx * Rz"""
    return ry(b) @ rx(a) @ rz(c)


def inv(m):
    r = m[:3, :3].T
    out = np.eye(4)
    out[:3, :3] = r
    out[:3, 3] = -r @ m[:3, 3]
    return out


def lerp_identidade(alvo, peso):
    """Equivalente a CFrame.identity:Lerp(alvo, peso)"""
    if peso >= 0.999:
        return alvo
    r = alvo[:3, :3]
    angulo = math.acos(max(-1.0, min(1.0, (np.trace(r) - 1) / 2)))
    out = np.eye(4)
    if angulo > 1e-6:
        eixo = np.array([r[2, 1] - r[1, 2], r[0, 2] - r[2, 0], r[1, 0] - r[0, 1]]) / (2 * math.sin(angulo))
        a = angulo * peso
        k = np.array([[0, -eixo[2], eixo[1]], [eixo[2], 0, -eixo[0]], [-eixo[1], eixo[0], 0]])
        out[:3, :3] = np.eye(3) + math.sin(a) * k + (1 - math.cos(a)) * (k @ k)
    out[:3, 3] = alvo[:3, 3] * peso
    return out


# ---------------------------------------------------------------------------
# Esqueleto R15 (aproximado do R15 em blocos padrão do Roblox)
# junta: (parte pai, parte filha, C0 no pai, C1 na filha, nome lógico)
# ---------------------------------------------------------------------------

PARTES = {
    "LowerTorso": (2, 0.4, 1),
    "UpperTorso": (2, 1.6, 1),
    "Head": (1.2, 1.2, 1.2),
    "RightUpperArm": (1, 1.17, 1),
    "RightLowerArm": (1, 1.05, 1),
    "RightHand": (1, 0.3, 1),
    "LeftUpperArm": (1, 1.17, 1),
    "LeftLowerArm": (1, 1.05, 1),
    "LeftHand": (1, 0.3, 1),
    "RightUpperLeg": (1, 1.22, 1),
    "RightLowerLeg": (1, 1.19, 1),
    "RightFoot": (1, 0.3, 1),
    "LeftUpperLeg": (1, 1.22, 1),
    "LeftLowerLeg": (1, 1.19, 1),
    "LeftFoot": (1, 0.3, 1),
}

JUNTAS = [
    ("HRP", "LowerTorso", cf(0, -1, 0), cf(0, -0.2, 0), "raiz"),
    ("LowerTorso", "UpperTorso", cf(0, 0.2, 0), cf(0, -0.8, 0), "cintura"),
    ("UpperTorso", "Head", cf(0, 0.8, 0), cf(0, -0.5, 0), "pescoco"),
    ("UpperTorso", "RightUpperArm", cf(1, 0.56, 0), cf(-0.5, 0.42, 0), "ombroD"),
    ("RightUpperArm", "RightLowerArm", cf(0, -0.33, 0), cf(0, 0.26, 0), "cotoveloD"),
    ("RightLowerArm", "RightHand", cf(0, -0.5, 0), cf(0, 0.125, 0), "pulsoD"),
    ("UpperTorso", "LeftUpperArm", cf(-1, 0.56, 0), cf(0.5, 0.42, 0), "ombroE"),
    ("LeftUpperArm", "LeftLowerArm", cf(0, -0.33, 0), cf(0, 0.26, 0), "cotoveloE"),
    ("LeftLowerArm", "LeftHand", cf(0, -0.5, 0), cf(0, 0.125, 0), "pulsoE"),
    ("LowerTorso", "RightUpperLeg", cf(0.5, -0.2, 0), cf(0, 0.42, 0), "quadrilD"),
    ("RightUpperLeg", "RightLowerLeg", cf(0, -0.41, 0), cf(0, 0.39, 0), "joelhoD"),
    ("RightLowerLeg", "RightFoot", cf(0, -0.55, 0), cf(0, 0.1, 0), "tornozeloD"),
    ("LowerTorso", "LeftUpperLeg", cf(-0.5, -0.2, 0), cf(0, 0.42, 0), "quadrilE"),
    ("LeftUpperLeg", "LeftLowerLeg", cf(0, -0.41, 0), cf(0, 0.39, 0), "joelhoE"),
    ("LeftLowerLeg", "LeftFoot", cf(0, -0.55, 0), cf(0, 0.1, 0), "tornozeloE"),
]

CORES = {
    "Head": (230, 200, 160),
    "UpperTorso": (70, 110, 190),
    "LowerTorso": (60, 80, 140),
    "RightUpperArm": (200, 90, 80),
    "RightLowerArm": (220, 120, 100),
    "RightHand": (240, 200, 160),
    "LeftUpperArm": (90, 170, 90),
    "LeftLowerArm": (120, 200, 120),
    "LeftHand": (240, 200, 160),
}


def montar(transformacoes):
    """Devolve { parte: CFrame no mundo } para as transformações das juntas."""
    mundo = {"HRP": cf(0, 3, 0)}
    for pai, filha, c0, c1, nome in JUNTAS:
        t = transformacoes.get(nome, np.eye(4))
        mundo[filha] = mundo[pai] @ c0 @ t @ inv(c1)
    return mundo


# ---------------------------------------------------------------------------
# Mistura das camadas (igual a Animacoes.animarPersonagem)
# ---------------------------------------------------------------------------

PESO_POSTURA = 0.75


def lerp_cf(a, b, t):
    """Equivalente a a:Lerp(b, t) (rotação pelo caminho mais curto)."""
    rel = inv(a) @ b
    return a @ lerp_identidade(rel, t)


def cframe_de(v):
    v = list(v) + [0] * (6 - len(v))
    return cf(v[3], v[4], v[5]) @ euler_yxz(v[0], v[1], v[2])


FLUTUAR = None  # main() preenche com a levitação da classe (Mago)


def combinar(postura, parado, pose, peso_parado=0.9, movendo=False):
    """Mistura as camadas como rotações (igual a Animacoes.animarPersonagem)."""
    final = {}
    especiais = {}

    def camada(p, peso):
        for junta, valor in p.items():
            if junta in ("puxar", "brilho", "flechaMao"):
                especiais[junta] = valor[0] * peso * (valor[6] if len(valor) > 6 else 1)
                continue
            w = peso * (valor[6] if len(valor) > 6 else 1)
            if w > 0.001:
                alvo = cframe_de(valor)
                if junta in final:
                    atual, pa = final[junta]
                    final[junta] = (lerp_cf(atual, alvo, w), pa + (1 - pa) * w)
                else:
                    final[junta] = (alvo, w)

    camada(postura, PESO_POSTURA)
    if parado:
        camada(parado, peso_parado)
    if pose:
        camada(pose, 1)
    if FLUTUAR:
        camada(FLUTUAR["pernasMovendo" if movendo else "pernas"], 1)
        raiz, _ = final.get("raiz", (np.eye(4), 1))
        final["raiz"] = (cf(0, FLUTUAR["altura"], 0) @ raiz, 1)
    transf = {junta: lerp_identidade(m, min(peso, 1)) for junta, (m, peso) in final.items()}
    return transf, especiais


# ---------------------------------------------------------------------------
# Armas (mesmas medidas de Server/Armas.luau)
# ---------------------------------------------------------------------------


def lamina_espada(mundo):
    """CFrame da lâmina da espada do Cavaleiro (igual a Armas.espadaPronta: cabo no meio da mão,
    a 1,8 do centro da lâmina; a ponta fica no +Z)."""
    return mundo["RightHand"] @ rx(math.radians(-20)) @ ry(math.pi) @ cf(0, 0, 1.8)


ESCUDO_EM_DEFESA = False  # main() liga quando a ação é de defesa


def escudo_cavaleiro(mundo):
    """CFrame do escudo, preso na parte de fora do antebraço (igual a Server/Armas.luau):
    a frente do escudo (lado -X dele, com o emblema) fica no +Z do antebraço e o "para cima"
    do escudo (Y) aponta para a mão. Com o antebraço em pé na frente do rosto, o escudo fica
    erguido e de frente."""
    if not ESCUDO_EM_DEFESA:
        # carregado ao lado do corpo (Animacoes: ESCUDO_CARREGADO)
        return mundo["LeftLowerArm"] @ cf(-0.62, 0, 0)
    giro = np.eye(4)
    giro[:3, :3] = np.array([[0, 0, -1], [0, -1, 0], [-1, 0, 0]], float)
    return mundo["LeftLowerArm"] @ cf(0, 0, 0.62) @ giro


def haste_cajado(mundo):
    """CFrame da haste do cajado do Mago (Armas.construirCajado: em pé, a mão segura 1,2 abaixo do centro)."""
    return mundo["RightHand"] @ cf(0, -0.15, 0) @ cf(0, 1.2, 0)


def arco_arqueiro(mundo):
    """CFrame da empunhadura do arco (Armas.construirArco, na mão esquerda): em pé no eixo Y,
    os braços curvam para +Z (para quem segura) e a flecha sai para -Z."""
    return mundo["LeftHand"] @ cf(0, -0.15, 0) @ rx(math.radians(-90))


def segmento_caixa(base, a, b, espessura):
    """Caixa entre os pontos a e b (no espaço de 'base'), como Armas.segmento."""
    a, b = np.array(a, float), np.array(b, float)
    meio = (a + b) / 2
    frente = b - a
    comprimento = np.linalg.norm(frente)
    z = -frente / comprimento  # CFrame.lookAt: o -Z aponta para b
    cima = np.array([0, 1.0, 0]) if abs(z[1]) < 0.99 else np.array([1.0, 0, 0])
    x = np.cross(cima, z)
    x /= np.linalg.norm(x)
    y = np.cross(z, x)
    m = np.eye(4)
    m[:3, 0], m[:3, 1], m[:3, 2], m[:3, 3] = x, y, z, meio
    return base @ m, (espessura, espessura, comprimento)


def caixas_do_arco(mundo, puxar=0.0, flecha_mao=0.0):
    arco = arco_arqueiro(mundo)
    caixas = [(arco, (0.34, 1, 0.34), (92, 58, 34), "Arco")]
    pontos = [(0, 0.5, 0), (0, 1.5, 0.18), (0, 2.35, 0.6)]
    for lado in (-1, 1):
        for i in range(len(pontos) - 1):
            a = (0, pontos[i][1] * lado, pontos[i][2])
            b = (0, pontos[i + 1][1] * lado, pontos[i + 1][2])
            m, tam = segmento_caixa(arco, a, b, 0.26)
            caixas.append((m, tam, (96, 64, 40), "BracoArco"))
        caixas.append((arco @ cf(0, 2.35 * lado, 0.6), (0.32, 0.32, 0.32), (232, 186, 82), "PontaArco"))
    caixas.append((arco @ cf(0, 0, -0.2), (0.3, 0.3, 0.3), (96, 214, 120), "Gema"))
    # corda: do topo ao encaixe e do encaixe à base (Animacoes: o encaixe vai para +Z ao puxar)
    z = 0.62 + min(max(puxar, 0), 1.3) * 1.6
    for ponta in ((0, 2.32, 0.62), (0, -2.32, 0.62)):
        m, tam = segmento_caixa(arco, ponta, (0, 0, z), 0.07)
        caixas.append((m, tam, (255, 240, 210), "Corda"))
    if puxar > 0.15:
        flecha = arco @ cf(0, 0, z - 1.35)
        caixas.append((flecha, (0.12, 0.12, 2.7), (160, 120, 80), "Flecha"))
        caixas.append((flecha @ cf(0, 0, -1.45), (0.22, 0.22, 0.4), (96, 214, 120), "PontaFlecha"))
    elif flecha_mao > 0.5:
        flecha = mundo["RightHand"] @ cf(0, 0.9, 0) @ rx(math.radians(90))
        caixas.append((flecha, (0.12, 0.12, 2.7), (160, 120, 80), "Flecha"))
    # aljava nas costas (Armas: UpperTorso * (0.35, 0.2, 0.75) * em pé * -20°)
    aljava = mundo["UpperTorso"] @ cf(0.35, 0.2, 0.75) @ rz(math.radians(90)) @ rx(math.radians(-20))
    caixas.append((aljava, (2.3, 0.75, 0.75), (92, 58, 34), "Aljava"))
    caixas.append((aljava @ cf(1.35, 0, 0), (0.5, 0.36, 0.35), (96, 214, 120), "Penas"))
    return caixas


def lamina_adaga(mundo, mao="RightHand"):
    """CFrame da lâmina da adaga do Assassino (Armas.construirAdaga: a mão segura em z = -1,25;
    a ponta fica no +Z)."""
    return mundo[mao] @ cf(0, -0.15, 0) @ rx(math.radians(-30)) @ ry(math.pi) @ cf(0, 0, 1.3)


def caixas_das_adagas(mundo):
    caixas = []
    for mao in ("RightHand", "LeftHand"):
        lamina = lamina_adaga(mundo, mao)
        caixas.append((lamina, (0.26, 0.1, 1.9), (70, 70, 82), "LaminaAdaga"))
        caixas.append((lamina @ cf(0, 0, 0.1), (0.06, 0.12, 1.5), (235, 60, 90), "Fio"))
        caixas.append((lamina @ cf(0, 0, -0.98), (0.9, 0.18, 0.18), (40, 36, 46), "GuardaAdaga"))
        caixas.append((lamina @ cf(0, 0, -1.35), (0.26, 0.26, 0.7), (34, 30, 38), "CaboAdaga"))
    return caixas


def ponta_da_adaga(mundo):
    return (lamina_adaga(mundo) @ np.array([0, 0, 0.95, 1]))[:3]


def ponta_do_arco(mundo):
    return (arco_arqueiro(mundo) @ np.array([0, 0, -1.5, 1]))[:3]


def caixas_da_classe(classe, mundo, especiais=None):
    especiais = especiais or {}
    caixas = []
    for nome, tamanho in PARTES.items():
        caixas.append((mundo[nome], tamanho, CORES.get(nome, (150, 150, 160)), nome))
    if classe == "mago":
        haste = haste_cajado(mundo)
        caixas.append((haste, (0.3, 6.4, 0.3), (110, 74, 46), "Haste"))
        caixas.append((haste @ cf(0, 3.75, 0) @ ry(math.radians(45)), (0.75, 1.2, 0.75), (190, 110, 255), "Cristal"))
        caixas.append((haste @ cf(0, 3.05, 0), (0.9, 0.25, 0.25), (232, 186, 82), "Garra"))
        caixas.append((haste @ cf(0, -3.2, 0), (0.4, 0.4, 0.4), (232, 186, 82), "Ponteira"))
    if classe == "arqueiro":
        caixas += caixas_do_arco(mundo, especiais.get("puxar", 0.0), especiais.get("flechaMao", 0.0))
    if classe == "assassino":
        caixas += caixas_das_adagas(mundo)
    if classe in ("cavaleiro", "assassino"):
        if classe == "cavaleiro":
            lamina = lamina_espada(mundo)
            caixas.append((lamina, (0.32, 0.16, 4.4), (215, 225, 240), "Lamina"))
            caixas.append((lamina @ cf(0, 0, 1.9), (0.34, 0.18, 0.6), (255, 240, 120), "PontaLamina"))
            caixas.append((lamina @ cf(0, 0, -1.15), (1.6, 0.3, 0.34), (232, 186, 82), "Guarda"))
            caixas.append((lamina @ cf(0, 0, -1.75), (0.36, 0.36, 1.05), (92, 58, 34), "Cabo"))
            # escudo no antebraço esquerdo; a face da frente (com o emblema) é o lado -X
            escudo = escudo_cavaleiro(mundo)
            caixas.append((escudo, (0.3, 2.9, 2.3), (46, 78, 150), "Escudo"))
            caixas.append((escudo @ cf(-0.17, 0, 0), (0.05, 1.6, 0.26), (120, 200, 255), "Emblema"))
            caixas.append((escudo @ cf(-0.17, 0.25, 0), (0.05, 0.26, 1.2), (120, 200, 255), "Emblema2"))
    return caixas


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

FACES = [
    ((0, 1, 3, 2), (-1, 0, 0)),
    ((4, 6, 7, 5), (1, 0, 0)),
    ((0, 4, 5, 1), (0, -1, 0)),
    ((2, 3, 7, 6), (0, 1, 0)),
    ((0, 2, 6, 4), (0, 0, -1)),
    ((1, 5, 7, 3), (0, 0, 1)),
]


def cantos(m, tamanho):
    sx, sy, sz = (v / 2 for v in tamanho)
    pts = []
    for x in (-sx, sx):
        for y in (-sy, sy):
            for z in (-sz, sz):
                pts.append((m @ np.array([x, y, z, 1]))[:3])
    return pts


class Camera:
    def __init__(self, posicao, alvo, escala, centro_tela, cima_ref=(0, 1, 0)):
        self.pos = np.array(posicao, float)
        frente = np.array(alvo, float) - self.pos
        self.frente = frente / np.linalg.norm(frente)
        direita = np.cross(self.frente, np.array(cima_ref, float))
        self.direita = direita / np.linalg.norm(direita)
        self.cima = np.cross(self.direita, self.frente)
        self.escala = escala
        self.centro = centro_tela
        self.alvo = np.array(alvo, float)

    def projetar(self, p):
        d = np.array(p) - self.alvo
        return (self.centro[0] + d @ self.direita * self.escala, self.centro[1] - d @ self.cima * self.escala)

    def profundidade(self, p):
        return (np.array(p) - self.pos) @ self.frente


LUZ = np.array([0.4, 0.8, -0.45])
LUZ = LUZ / np.linalg.norm(LUZ)


def desenhar(draw, camera, caixas, rastro=None):
    # chão: grade e seta para a frente (-Z)
    for i in range(-4, 5):
        for a, b in (((i * 2, 0, -8), (i * 2, 0, 8)), ((-8, 0, i * 2), (8, 0, i * 2))):
            draw.line([camera.projetar(a), camera.projetar(b)], fill=(70, 70, 82), width=1)
    draw.line([camera.projetar((0, 0.02, 0)), camera.projetar((0, 0.02, -6))], fill=(255, 80, 80), width=3)
    draw.text(camera.projetar((0, 0.02, -6.4)), "frente", fill=(255, 120, 120))

    faces = []
    for m, tamanho, cor, nome in caixas:
        pts = cantos(m, tamanho)
        rot = m[:3, :3]
        for idx, normal in FACES:
            n = rot @ np.array(normal, float)
            if n @ camera.frente >= 0:
                continue
            centro = sum(pts[i] for i in idx) / 4
            luz = 0.45 + 0.55 * max(0.0, float(n @ LUZ))
            c = tuple(int(min(255, v * luz)) for v in cor)
            faces.append((camera.profundidade(centro), [camera.projetar(pts[i]) for i in idx], c))
    faces.sort(key=lambda f: -f[0])
    for _, poligono, c in faces:
        draw.polygon(poligono, fill=c, outline=(20, 20, 26))
    # caminho da ponta da espada durante a animação (amarelo = começo, vermelho = fim)
    if rastro and len(rastro) > 1:
        for i in range(len(rastro) - 1):
            k = i / (len(rastro) - 1)
            cor = (255, int(230 - 180 * k), int(60 - 40 * k))
            draw.line([camera.projetar(rastro[i]), camera.projetar(rastro[i + 1])], fill=cor, width=2)


# posição da câmera e "para cima" da imagem (na vista de cima, a frente do personagem fica para cima)
VISTAS = {
    "3/4 frente": ((6.5, 6.0, -9.0), (0, 1, 0)),
    "lado": ((11.0, 3.5, 0.0), (0, 1, 0)),
    "cima": ((0.0, 14.0, 0.0), (0, 0, -1)),
    "costas": ((-5.0, 6.0, 9.0), (0, 1, 0)),
}


def renderizar(quadros, titulo, saida, vistas=("3/4 frente", "lado", "cima")):
    """quadros: lista de (rótulo, caixas, rastro da ponta da espada ou None)"""
    largura_celula, altura_celula = 300, 300
    img = Image.new("RGB", (largura_celula * len(quadros), altura_celula * len(vistas) + 30), (26, 26, 34))
    draw = ImageDraw.Draw(img)
    try:
        fonte = ImageFont.truetype("arial.ttf", 14)
    except OSError:
        fonte = ImageFont.load_default()
    draw.text((8, 6), titulo, fill=(255, 230, 160), font=fonte)
    for coluna, (rotulo, caixas, rastro) in enumerate(quadros):
        for linha, vista in enumerate(vistas):
            ox, oy = coluna * largura_celula, 30 + linha * altura_celula
            posicao, cima = VISTAS[vista]
            camera = Camera(posicao, (0, 2.6, 0), 28, (ox + largura_celula / 2, oy + altura_celula / 2 + 20), cima)
            draw.rectangle([ox, oy, ox + largura_celula - 1, oy + altura_celula - 1], fill=(36, 36, 46))
            desenhar(draw, camera, caixas, rastro)
            draw.rectangle([ox, oy, ox + largura_celula - 1, oy + altura_celula - 1], outline=(80, 80, 96))
            draw.text((ox + 6, oy + 4), f"{rotulo}  [{vista}]", fill=(220, 220, 230), font=fonte)
    img.save(saida)


def carregar_poses(luau, classe):
    script = os.path.join(RAIZ, "ferramentas", "poses_json.luau")
    resultado = subprocess.run([luau, script, "-a", classe], capture_output=True, text=True, cwd=RAIZ)
    if resultado.returncode != 0:
        print(resultado.stderr or resultado.stdout)
        sys.exit(1)
    return json.loads(resultado.stdout)


def ponta_da_espada(mundo):
    return (lamina_espada(mundo) @ np.array([0, 0, 2.2, 1]))[:3]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--luau", required=True)
    p.add_argument("--classe", default="cavaleiro")
    p.add_argument("--acao", default=None)
    p.add_argument("--tempos", default=None, help="lista de tempos, ex.: 0,0.08,0.13,0.2")
    p.add_argument("--quadros", type=int, default=6)
    p.add_argument("--sem-parado", action="store_true")
    p.add_argument("--vistas", default="3/4 frente,lado,cima")
    p.add_argument("--saida", default="poses.png")
    args = p.parse_args()

    global ESCUDO_EM_DEFESA
    ESCUDO_EM_DEFESA = args.acao in ("defender", "bloqueio")
    dados = carregar_poses(args.luau, args.classe)
    global FLUTUAR
    FLUTUAR = dados.get("flutuar")
    postura = dados["postura"]
    parado = None if args.sem_parado else dados["parado"]

    quadros = []
    if args.acao is None:
        transf, esp = combinar(postura, parado, None)
        quadros.append(("parado", caixas_da_classe(args.classe, montar(transf), esp), None))
        titulo = f"{args.classe}: postura parada"
    else:
        acao = dados["acoes"][args.acao]
        amostras = acao["quadros"]
        if args.tempos:
            tempos = [float(t) for t in args.tempos.split(",")]
        else:
            fim = acao["duracao"]
            tempos = [fim * i / (args.quadros - 1) for i in range(args.quadros)]
        # caminho da ponta da espada na animação inteira
        rastro = None
        if args.classe == "cavaleiro":
            rastro = [ponta_da_espada(montar(combinar(postura, parado, q["pose"])[0])) for q in amostras]
        elif args.classe == "mago":
            rastro = [(haste_cajado(montar(combinar(postura, parado, q["pose"])[0])) @ np.array([0, 3.75, 0, 1]))[:3] for q in amostras]
        elif args.classe == "assassino":
            rastro = [ponta_da_adaga(montar(combinar(postura, parado, q["pose"])[0])) for q in amostras]
        elif args.classe == "arqueiro":
            rastro = [ponta_do_arco(montar(combinar(postura, parado, q["pose"])[0])) for q in amostras]
        for t in tempos:
            amostra = min(amostras, key=lambda q: abs(q["t"] - t))
            transf, esp = combinar(postura, parado, amostra["pose"])
            quadros.append((f"t={amostra['t']:.2f}", caixas_da_classe(args.classe, montar(transf), esp), rastro))
        titulo = f"{args.classe}: {args.acao} (duração {acao['duracao']:.2f}s)"
    renderizar(quadros, titulo, args.saida, tuple(args.vistas.split(",")))
    print("salvo em", args.saida)


if __name__ == "__main__":
    main()
