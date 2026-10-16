"""Gera o cenário do lobby (mapas/Lobby.rbxmx): o acampamento de fantasia, visível e editável
no Studio (Workspace > Mapa > Lobby).

    py ferramentas/gerar_lobby.py            (gera mapas/Lobby.rbxmx e mapas/lobby_visto_de_cima.png)

ATENÇÃO: rodar de novo APAGA as edições feitas à mão no Studio (o build.py guarda essas edições
em mapas/Lobby.rbxmx). Só rode para recomeçar o lobby do zero.

Estilo: tudo em peças lisas (SmoothPlastic) com cores vivas, sem textura realista; árvores,
pedras, cogumelos, samambaias e grama vêm do pacote de natureza estilizada
(cenario/NaturezaEstilizada.rbxmx, tirado do Studio por ferramentas/extrair_cenario.py).

O que é interativo (portal, altares, loja, letreiros, placa) é montado por código em
server/Lobby.luau, em cima dos MARCADORES (pasta Marcadores): mover um marcador no Studio muda
onde aquilo aparece no jogo.
"""
import copy
import math
import os
import random
import re
import xml.etree.ElementTree as ET

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIBLIOTECA = os.path.join(RAIZ, "cenario", "NaturezaEstilizada.rbxmx")
SAIDA = os.path.join(RAIZ, "mapas", "Lobby.rbxmx")
PREVIA = os.path.join(RAIZ, "mapas", "lobby_visto_de_cima.png")

rng = random.Random(42)

# ---------------------------------------------------------------------------------------------
# Paleta (fantasia viva, sem textura)
# ---------------------------------------------------------------------------------------------
GRAMA = (108, 196, 74)
GRAMA_CLARA = (132, 214, 88)
GRAMA_ESCURA = (88, 172, 64)
COLINA = (98, 184, 70)
COLINA_ESCURA = (82, 164, 62)
TERRA = (224, 186, 124)
TERRA_BORDA = (198, 156, 98)
PEDRA_CLARA = (232, 216, 186)
PEDRA_MEDIA = (200, 176, 146)
PEDRA_MIOLO = (242, 232, 210)
LILAS = (182, 168, 208)
LILAS_CLARO = (216, 208, 234)
LILAS_ESCURO = (112, 98, 140)
BRANCO_PEDRA = (244, 240, 252)
MADEIRA = (160, 106, 64)
MADEIRA_CLARA = (196, 140, 86)
MADEIRA_ESCURA = (128, 82, 50)
CERCA = (236, 172, 72)
OURO = (236, 192, 92)
ROXO = (150, 70, 255)
ROXO_BANDEIRA = (126, 70, 205)
TELHADO = (84, 112, 216)
AGUA = (86, 196, 255)
AGUA_FUNDA = (62, 160, 240)
VERMELHO_LONA = (222, 62, 72)
CREME_LONA = (250, 236, 210)
FLORES = [(255, 132, 200), (255, 222, 84), (255, 250, 240), (126, 176, 255), (255, 160, 90)]

MATERIAIS = {"Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Glass": 1568, "ForceField": 1584}
FORMAS = {"bola": 0, "bloco": 1, "cilindro": 2}


def cores_das_classes():
    """Ordem e cor de cada classe, lidas de src/shared/Classes.luau."""
    texto = open(os.path.join(RAIZ, "src", "shared", "Classes.luau"), encoding="utf-8").read()
    ordem = re.findall(r'"(\w+)"', re.search(r"Classes\.ordem = \{([^}]*)\}", texto).group(1))
    cores = {}
    for classe in ordem:
        bloco = texto[texto.index(f"\t{classe} = {{"):]
        r, g, b = re.search(r"cor = Color3\.fromRGB\((\d+), (\d+), (\d+)\)", bloco).groups()
        cores[classe] = (int(r), int(g), int(b))
    return ordem, cores


# ---------------------------------------------------------------------------------------------
# CFrame (matriz 4x4, igual ao Roblox: colunas = direita, cima, trás)
# ---------------------------------------------------------------------------------------------
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


EM_PE = rz(math.pi / 2)  # cilindro do Roblox fica no eixo X; isto o põe em pé (eixo Y)

# ---------------------------------------------------------------------------------------------
# XML do Roblox
# ---------------------------------------------------------------------------------------------
_proximo = [0]


def referente():
    _proximo[0] += 1
    return f"RBXLOBBY{_proximo[0]:07d}"


def numero(v):
    return f"{float(v):.4f}".rstrip("0").rstrip(".") if abs(v) > 1e-9 else "0"


def p_cframe(props, nome, m):
    e = ET.SubElement(props, "CoordinateFrame", {"name": nome})
    for chave, valor in zip(("X", "Y", "Z"), m[:3, 3]):
        ET.SubElement(e, chave).text = numero(valor)
    for i in range(3):
        for j in range(3):
            ET.SubElement(e, f"R{i}{j}").text = numero(m[i, j])


def p_vec3(props, nome, v):
    e = ET.SubElement(props, "Vector3", {"name": nome})
    for chave, valor in zip(("X", "Y", "Z"), v):
        ET.SubElement(e, chave).text = numero(valor)


def p_simples(props, tipo, nome, valor):
    if isinstance(valor, bool):
        valor = "true" if valor else "false"
    ET.SubElement(props, tipo, {"name": nome}).text = str(valor)


def p_cor8(props, rgb):
    r, g, b = rgb
    ET.SubElement(props, "Color3uint8", {"name": "Color3uint8"}).text = str(0xFF000000 | (r << 16) | (g << 8) | b)


def novo_item(pai, classe, nome):
    item = ET.SubElement(pai, "Item", {"class": classe, "referent": referente()})
    props = ET.SubElement(item, "Properties")
    p_simples(props, "string", "Name", nome)
    return item, props


def pasta(pai, nome):
    return novo_item(pai, "Folder", nome)[0]


def modelo(pai, nome):
    return novo_item(pai, "Model", nome)[0]


def parte(pai, nome, tamanho, m, cor, material="SmoothPlastic", forma="bloco", colide=True, transp=0.0,
          sombra=True, refl=0.0, classe="Part"):
    item, props = novo_item(pai, classe, nome)
    p_simples(props, "bool", "Anchored", True)
    p_cframe(props, "CFrame", m)
    p_simples(props, "bool", "CanCollide", colide)
    p_simples(props, "bool", "CanQuery", colide)
    p_simples(props, "bool", "CanTouch", colide)
    p_simples(props, "bool", "CastShadow", sombra)
    p_cor8(props, cor)
    p_simples(props, "token", "Material", MATERIAIS[material])
    p_simples(props, "float", "Reflectance", refl)
    p_simples(props, "float", "Transparency", transp)
    p_simples(props, "token", "TopSurface", 0)
    p_simples(props, "token", "BottomSurface", 0)
    if classe == "Part":
        p_simples(props, "token", "shape", FORMAS[forma])
    p_vec3(props, "size", tamanho)
    return item


def luz(pai, nome, cor, alcance, brilho):
    """PointLight. As de nome "LuzChama" tremulam no jogo (server/Lobby.luau marca com "Chama")."""
    item, props = novo_item(pai, "PointLight", nome)
    e = ET.SubElement(props, "Color3", {"name": "Color"})
    for chave, valor in zip("RGB", cor):
        ET.SubElement(e, chave).text = numero(valor / 255)
    p_simples(props, "float", "Brightness", brilho)
    p_simples(props, "float", "Range", alcance)
    p_simples(props, "bool", "Shadows", False)
    return item


def disco(pai, nome, x, y, z, diametro, espessura, cor, **extra):
    """Cilindro deitado (eixo vertical): chão, praça, lago, manchas de grama."""
    return parte(pai, nome, (espessura, diametro, diametro), cf(x, y, z) @ EM_PE, cor, forma="cilindro", **extra)


def coluna(pai, nome, x, y, z, diametro, altura, cor, **extra):
    """Cilindro em pé com o centro em y."""
    return parte(pai, nome, (altura, diametro, diametro), cf(x, y, z) @ EM_PE, cor, forma="cilindro", **extra)


def marcador(pai, nome, x, y, z, tamanho=(2, 2, 2)):
    """Ponto que o código usa para montar algo interativo. No Studio aparece rosa e meio
    transparente; no jogo fica invisível."""
    return parte(pai, nome, tamanho, cf(x, y, z), (255, 80, 200), material="Neon", colide=False, transp=0.65, sombra=False)


# ---------------------------------------------------------------------------------------------
# Biblioteca (pacote de natureza estilizada)
# ---------------------------------------------------------------------------------------------
class Biblioteca:
    def __init__(self, caminho):
        raiz = ET.parse(caminho).getroot()
        self.compartilhados = {t.get("md5"): t.text or "" for b in raiz.findall("SharedStrings") for t in b}
        self.ativos = {}
        for item in raiz.iter("Item"):
            if item.get("class") in ("Model", "MeshPart"):
                nome = item.find("./Properties/string[@name='Name']").text
                self.ativos.setdefault(nome, item)
        self.usados = set()

    @staticmethod
    def _ler_cframe(e):
        m = np.eye(4)
        m[:3, 3] = [float(e.find(k).text) for k in "XYZ"]
        for i in range(3):
            for j in range(3):
                m[i, j] = float(e.find(f"R{i}{j}").text)
        return m

    @staticmethod
    def _escrever_cframe(e, m):
        for chave, valor in zip("XYZ", m[:3, 3]):
            e.find(chave).text = numero(valor)
        for i in range(3):
            for j in range(3):
                e.find(f"R{i}{j}").text = numero(m[i, j])

    def _pecas(self, item):
        # (iter já inclui o próprio item: grama, samambaia e pedra são uma MeshPart só, e antes
        # entravam duas vezes, indo parar longe do mapa)
        return [p for p in item.iter("Item") if p.get("class") in ("MeshPart", "Part")]

    def colocar(self, pai, nome, x, z, rotacao=0.0, escala=1.0, y=0.0, cor=None, colide=None, sombra=None):
        """Copia um ativo da biblioteca com a base (centro de baixo) em (x, y, z)."""
        original = self.ativos[nome]
        copia = copy.deepcopy(original)
        pecas = self._pecas(copia)
        # caixa que envolve o ativo (base = centro de baixo)
        minimos, maximos = [], []
        for p in pecas:
            m = self._ler_cframe(p.find("./Properties/CoordinateFrame[@name='CFrame']"))
            tamanho = np.array([float(c.text) for c in p.find("./Properties/Vector3[@name='size']")])
            meio = np.abs(m[:3, :3]) @ (tamanho / 2)
            minimos.append(m[:3, 3] - meio)
            maximos.append(m[:3, 3] + meio)
        baixo, cima = np.min(minimos, 0), np.max(maximos, 0)
        base = np.array([(baixo[0] + cima[0]) / 2, baixo[1], (baixo[2] + cima[2]) / 2])
        giro = ry(rotacao)[:3, :3]
        destino = np.array([x, y, z])

        def mover(m):
            novo = np.eye(4)
            novo[:3, :3] = giro @ m[:3, :3]
            novo[:3, 3] = destino + giro @ ((m[:3, 3] - base) * escala)
            return novo

        for p in pecas:
            props = p.find("Properties")
            e = props.find("./CoordinateFrame[@name='CFrame']")
            self._escrever_cframe(e, mover(self._ler_cframe(e)))
            tamanho = props.find("./Vector3[@name='size']")
            for c in tamanho:
                c.text = numero(float(c.text) * escala)
            pivo = props.find("./CoordinateFrame[@name='PivotOffset']")
            if pivo is not None:
                for chave in "XYZ":
                    pivo.find(chave).text = numero(float(pivo.find(chave).text) * escala)
            if cor is not None:
                nome_peca = props.find("./string[@name='Name']").text
                if nome_peca in cor:
                    r, g, b = cor[nome_peca]
                    props.find("./Color3uint8[@name='Color3uint8']").text = str(0xFF000000 | (r << 16) | (g << 8) | b)
            if colide is not None:
                for chave in ("CanCollide", "CanTouch"):
                    q = props.find(f"./bool[@name='{chave}']")
                    if q is not None:
                        q.text = "true" if colide else "false"
            if sombra is not None:
                q = props.find("./bool[@name='CastShadow']")
                if q is not None:
                    q.text = "true" if sombra else "false"
        pivo_modelo = copia.find("./Properties/OptionalCoordinateFrame[@name='WorldPivotData']/CFrame")
        if pivo_modelo is not None:
            self._escrever_cframe(pivo_modelo, mover(self._ler_cframe(pivo_modelo)))
        # referências novas (a mesma árvore pode aparecer várias vezes)
        trocas = {}
        for item in copia.iter("Item"):
            novo = referente()
            trocas[item.get("referent")] = novo
            item.set("referent", novo)
        for ref in copia.iter("Ref"):
            if ref.text and ref.text.strip() in trocas:
                ref.text = trocas[ref.text.strip()]
        for e in copia.iter("SharedString"):
            if e.text:
                self.usados.add(e.text.strip())
        pai.append(copia)
        return copia, (cima - baixo) * escala


# ---------------------------------------------------------------------------------------------
# Onde não pode ter árvore / planta (estruturas, caminhos, lago)
# ---------------------------------------------------------------------------------------------
LAGO = (74.0, 62.0)
RAIO_LAGO = 21.0  # buraco no chão; a água de verdade (Terrain) é criada no jogo em cima da peça "Agua"
PRAIA = RAIO_LAGO + 3.4  # anel de areia em volta
NIVEL_AGUA = -1.2
FUNDO_LAGO = -6.5
POSICAO_PORTAL = (0.0, -46.0)

# santuários das classes: meia-lua a oeste da praça, cada um virado para o centro
RAIO_SANTUARIOS = 50.0
ANGULOS_SANTUARIOS = [213, 191, 169, 147]  # na ordem de Classes.ordem (o 1º fica do lado do portal)


def santuarios(ordem):
    """[(classe, x, z, giro)]: giro faz a frente (-Z) do santuário olhar para a praça."""
    lista = []
    for classe, graus in zip(ordem, ANGULOS_SANTUARIOS):
        a = math.radians(graus)
        x, z = math.cos(a) * RAIO_SANTUARIOS, math.sin(a) * RAIO_SANTUARIOS
        lista.append((classe, x, z, math.atan2(x, z)))
    return lista


SANTUARIOS_XZ = [(x, z) for _, x, z, _ in santuarios(["a", "b", "c", "d"])]


def distancia_segmento(x, z, x1, z1, x2, z2):
    dx, dz = x2 - x1, z2 - z1
    t = max(0.0, min(1.0, ((x - x1) * dx + (z - z1) * dz) / (dx * dx + dz * dz)))
    return math.hypot(x - (x1 + dx * t), z - (z1 + dz * t))


def livre(x, z, folga=0.0, lago=True):
    if math.hypot(x, z) < 36 + folga:  # praça
        return False
    if abs(x) < 42 + folga and z < -34 + folga:  # muralha, portal e círculo
        return False
    for sx, sz in SANTUARIOS_XZ:  # santuários das classes e o caminho até cada um
        if math.hypot(x - sx, z - sz) < 12 + folga:
            return False
        if distancia_segmento(x, z, sx * 0.6, sz * 0.6, sx, sz) < 4 + folga:
            return False
    if 28 - folga < x < 54 + folga and abs(z) < 14 + folga:  # loja
        return False
    if math.hypot(x - 16, z - 30) < 10 + folga:  # placa
        return False
    if abs(x) < 7 + folga and 30 < z < 60:  # caminho de trás
        return False
    if lago and math.hypot(x - LAGO[0], z - LAGO[1]) < RAIO_LAGO + 4 + folga:
        return False
    if distancia_segmento(x, z, 22, 22, 58, 46) < 5 + folga:  # caminho do lago
        return False
    if math.hypot(x, z - 22) < 7 + folga:  # onde o jogador nasce
        return False
    return abs(x) < 112 and abs(z) < 112


# ---------------------------------------------------------------------------------------------
# Construção
# ---------------------------------------------------------------------------------------------
def chao_com_buraco(pai, cx, cz, raio, largura_faixa=1.5, meia=220.0):
    """Chão de grama (topo em y = 0) com um buraco redondo para o lago: quatro placas grandes em
    volta de um quadrado e, dentro dele, faixas finas que param na borda do círculo (a praia de
    areia cobre os degrauzinhos que sobram)."""

    def placa(x1, x2, z1, z2):
        if x2 - x1 > 0.01 and z2 - z1 > 0.01:
            parte(pai, "Grama", (x2 - x1, 2, z2 - z1), cf((x1 + x2) / 2, -1, (z1 + z2) / 2), GRAMA)

    placa(-meia, cx - raio, -meia, meia)
    placa(cx + raio, meia, -meia, meia)
    placa(cx - raio, cx + raio, -meia, cz - raio)
    placa(cx - raio, cx + raio, cz + raio, meia)
    faixas = int(round(2 * raio / largura_faixa))
    for i in range(faixas):
        a = cx - raio + 2 * raio * i / faixas
        b = cx - raio + 2 * raio * (i + 1) / faixas
        perto = 0.0 if a <= cx <= b else min(abs(a - cx), abs(b - cx))
        meio_corda = math.sqrt(max(0.0, raio * raio - perto * perto))
        placa(a, b, cz - raio, cz - meio_corda)
        placa(a, b, cz + meio_corda, cz + raio)


def construir_chao(raiz):
    chao = pasta(raiz, "Chao")
    chao_com_buraco(chao, LAGO[0], LAGO[1], RAIO_LAGO)
    # manchas de grama clara e escura: dão o ar de pintura da referência
    manchas = pasta(chao, "ManchasDeGrama")
    for i in range(46):
        for _ in range(60):
            x, z = rng.uniform(-110, 110), rng.uniform(-110, 110)
            diametro = rng.uniform(12, 40)
            if math.hypot(x, z) > 38 and math.hypot(x - LAGO[0], z - LAGO[1]) > PRAIA + diametro / 2:
                break
        cor = GRAMA_CLARA if i % 2 == 0 else GRAMA_ESCURA
        disco(manchas, "Mancha", x, 0.02 + i * 0.0015, z, diametro, 0.1, cor, colide=False, sombra=False)
    # colinas redondas fechando o vale
    colinas = pasta(chao, "Colinas")
    for i in range(26):
        angulo = i / 26 * math.tau + rng.uniform(-0.06, 0.06)
        distancia = rng.uniform(140, 172)
        diametro = rng.uniform(70, 120)
        # colina não pode invadir o lago (a base dela no chão tem raio ~0,47 do diâmetro)
        while math.hypot(math.cos(angulo) * distancia - LAGO[0], math.sin(angulo) * distancia - LAGO[1]) < 0.47 * diametro + PRAIA + 6:
            distancia += 4
        parte(colinas, "Colina", (diametro, diametro * 0.7, diametro),
              cf(math.cos(angulo) * distancia, -diametro * 0.12, math.sin(angulo) * distancia),
              COLINA if i % 2 == 0 else COLINA_ESCURA, forma="bola")
    # caminhos de terra clara (com as pontas arredondadas)
    caminhos = pasta(chao, "Caminhos")

    def caminho(x1, z1, x2, z2, largura):
        comprimento = math.hypot(x2 - x1, z2 - z1)
        angulo = math.atan2(x2 - x1, z2 - z1)
        meio = cf((x1 + x2) / 2, 0.06, (z1 + z2) / 2) @ ry(angulo)
        parte(caminhos, "Caminho", (largura, 0.12, comprimento), meio, TERRA, colide=False, sombra=False)
        parte(caminhos, "Borda", (largura + 1.2, 0.1, comprimento), meio @ cf(0, -0.015, 0), TERRA_BORDA, colide=False, sombra=False)
        for px, pz in ((x1, z1), (x2, z2)):
            disco(caminhos, "Ponta", px, 0.06, pz, largura, 0.12, TERRA, colide=False, sombra=False)

    caminho(0, -30, 0, -40, 12)  # praça -> portal
    for sx, sz in SANTUARIOS_XZ:  # praça -> cada santuário de classe
        d = math.hypot(sx, sz)
        caminho(sx * 29 / d, sz * 29 / d, sx * (d - 7) / d, sz * (d - 7) / d, 5)
    caminho(30, 0, 36, 0, 9)  # praça -> loja
    caminho(0, 30, 0, 58, 8)  # praça -> trás
    caminho(22, 22, 58, 46, 6)  # praça -> lago
    return chao


def braseiro(pai, x, z):
    b = modelo(pai, "Braseiro")
    coluna(b, "Pe", x, 1.5, z, 1.3, 3, LILAS_ESCURO)
    coluna(b, "Tigela", x, 3.3, z, 2.9, 1, (78, 66, 96))
    coluna(b, "Aro", x, 3.75, z, 3.2, 0.3, OURO, colide=False)
    brasa = coluna(b, "Brasa", x, 3.85, z, 2.3, 0.3, (214, 96, 46), colide=False, sombra=False)  # o fogo é do pacote de VFX
    luz(brasa, "LuzChama", (255, 160, 80), 26, 2)


def lanterna(pai, x, z, giro=0.0):
    l = modelo(pai, "Lanterna")
    base = cf(x, 0, z) @ ry(giro)
    parte(l, "Poste", (0.6, 7, 0.6), base @ cf(0, 3.5, 0), MADEIRA)
    parte(l, "Braco", (0.4, 0.4, 1.8), base @ cf(0, 6.8, -0.7), MADEIRA)
    parte(l, "Caixa", (0.95, 1.25, 0.95), base @ cf(0, 6, -1.4), (255, 220, 150), transp=0.3, colide=False)
    parte(l, "Teto", (1.2, 0.3, 1.2), base @ cf(0, 6.75, -1.4), MADEIRA_ESCURA, colide=False)
    chama = parte(l, "Chama", (0.45, 0.45, 0.45), base @ cf(0, 6, -1.4), (255, 196, 96), material="Neon", colide=False, sombra=False)
    luz(chama, "LuzChama", (255, 190, 110), 18, 1.4)


def cerca(pai, x1, z1, x2, z2):
    c = modelo(pai, "Cerca")
    comprimento = math.hypot(x2 - x1, z2 - z1)
    angulo = math.atan2(x2 - x1, z2 - z1)
    postes = max(2, int(comprimento / 4) + 1)
    for i in range(postes):
        t = i / (postes - 1)
        px, pz = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
        parte(c, "Poste", (0.55, 3.2, 0.55), cf(px, 1.6, pz) @ ry(angulo), CERCA)
        parte(c, "Topo", (0.7, 0.3, 0.7), cf(px, 3.3, pz) @ ry(angulo), MADEIRA_CLARA)
    meio = cf((x1 + x2) / 2, 0, (z1 + z2) / 2) @ ry(angulo)
    for altura in (1.2, 2.4):
        parte(c, "Ripa", (0.25, 0.35, comprimento), meio @ cf(0, altura, 0), CERCA)


def construir_praca(raiz):
    praca = pasta(raiz, "Praca")
    disco(praca, "Praca", 0, -0.38, 0, 62, 1, PEDRA_CLARA)
    disco(praca, "AnelPraca", 0, -0.36, 0, 42, 1.05, PEDRA_MEDIA)
    disco(praca, "MioloPraca", 0, -0.34, 0, 38, 1.1, PEDRA_MIOLO)
    for i in range(8):
        angulo = i / 8 * math.tau
        parte(praca, "Raio", (0.6, 0.1, 18), cf(0, 0.22, 0) @ ry(angulo) @ cf(0, 0, -10), PEDRA_MEDIA, colide=False, sombra=False)
    parte(praca, "BaseObelisco", (7, 1.4, 7), cf(0, 0.7, 0), LILAS)
    parte(praca, "Degrau", (5, 1, 5), cf(0, 1.9, 0), LILAS_CLARO)
    parte(praca, "Obelisco", (2.6, 10, 2.6), cf(0, 7.4, 0), BRANCO_PEDRA)
    parte(praca, "PontaObelisco", (1.6, 1.6, 1.6), cf(0, 12.4, 0) @ ry(math.pi / 4) @ rx(math.pi / 4), OURO)
    for lado in range(4):
        parte(praca, "Runa", (0.2, 6, 0.6), cf(0, 7.4, 0) @ ry(lado * math.pi / 2) @ cf(1.32, 0, 0), (120, 190, 240),
              colide=False, sombra=False)
    # cristal que gira e flutua (o código liga o giro: tag "Girar")
    cristal = modelo(praca, "CristalFlutuante")
    parte(cristal, "Cristal", (2.4, 4, 2.4), cf(0, 16, 0) @ ry(math.pi / 4), (64, 150, 214), material="Neon", colide=False)
    parte(cristal, "Anel", (0.3, 6, 6), cf(0, 16, 0) @ rz(math.pi / 2) @ rx(math.radians(20)), OURO, forma="cilindro", colide=False)
    for angulo in (45, 135, 225, 315):
        r = math.radians(angulo)
        braseiro(praca, math.cos(r) * 17, math.sin(r) * 17)
    # bancos de tronco em volta da praça
    return praca


def construir_portal(raiz):
    portal = pasta(raiz, "Portal")
    z = -64
    parte(portal, "Muralha", (60, 24, 7), cf(0, 12, z), LILAS)
    parte(portal, "Rodape", (61, 2, 7.6), cf(0, 1, z), LILAS_ESCURO)
    parte(portal, "Cornija", (61, 1.6, 7.8), cf(0, 24.8, z), LILAS_CLARO)
    for i in range(-6, 7):
        parte(portal, "Ameia", (3, 3, 7.6), cf(i * 4.6, 27.1, z), LILAS_CLARO)
    for x in (-30, 30):
        torre = modelo(portal, "Torre")
        coluna(torre, "Torre", x, 17, z, 12, 34, (170, 158, 196))
        for y in (2, 12, 33):
            coluna(torre, "Faixa", x, y, z, 12.8, 1.2, LILAS_CLARO)
        # telhado cônico em degraus (azul) com a ponta dourada
        for i in range(7):
            coluna(torre, "Telhado", x, 34.6 + i * 1.5, z, 15 - i * 2, 1.5, TELHADO)
        parte(torre, "Ponta", (1.4, 1.4, 1.4), cf(x, 45.6, z), OURO, forma="bola")
        bandeira = parte(torre, "Bandeira", (5, 12, 0.3), cf(x, 20, z + 6.4), ROXO_BANDEIRA, colide=False)
        parte(torre, "Simbolo", (2.4, 2.4, 0.35), cf(x, 22, z + 6.6) @ rz(math.pi / 4), OURO, colide=False)
        lanterna(portal, x * 0.62, z + 8)
    # arco do portal (o redemoinho roxo é um efeito do pacote, ligado pelo código)
    for x in (-9.5, 9.5):
        parte(portal, "Coluna", (3, 22, 3.4), cf(x, 11, z + 4), (104, 86, 140))
        parte(portal, "Capitel", (3.8, 1, 4), cf(x, 22.5, z + 4), OURO)
    parte(portal, "Verga", (22, 3, 3.4), cf(0, 24.5, z + 4), (104, 86, 140))
    parte(portal, "Chave", (3.4, 3.4, 3.6), cf(0, 25, z + 4.3) @ rz(math.pi / 4), OURO, colide=False)
    # círculo onde o grupo se junta
    px, pz = POSICAO_PORTAL
    disco(portal, "Aro", px, 0.1, pz, 21, 0.4, LILAS_ESCURO)
    disco(portal, "Miolo", px, 0.12, pz, 18, 0.4, (92, 80, 120), colide=False)
    for i in range(4):
        angulo = i * math.pi / 2 + math.pi / 4
        x, zz = px + math.cos(angulo) * 11.5, pz + math.sin(angulo) * 11.5
        parte(portal, "PedraRunica", (1.6, 4, 1.2), cf(x, 2, zz) @ ry(-angulo), LILAS_ESCURO)
        parte(portal, "RunaPedra", (1.7, 1, 0.5), cf(x, 2.6, zz) @ ry(-angulo), (176, 120, 240), colide=False)
    return portal


def _ponto(m):
    return m[0, 3], m[1, 3], m[2, 3]


def _cavaleiro(s, L, cor, clara):
    # espada cravada na pedra (esquerda) e escudo encostado (direita)
    parte(s, "Pedra", (2, 1.2, 1.7), L(-3.5, 1.7, -1.6) @ ry(0.3), (150, 140, 172))
    parte(s, "Lamina", (0.22, 2.9, 0.62), L(-3.5, 3.4, -1.6) @ ry(0.3), (226, 232, 242), refl=0.15)
    parte(s, "Guarda", (0.36, 0.32, 2.1), L(-3.5, 4.95, -1.6) @ ry(0.3), OURO)
    parte(s, "Cabo", (0.3, 1, 0.3), L(-3.5, 5.6, -1.6) @ ry(0.3), MADEIRA_ESCURA)
    parte(s, "Pomo", (0.5, 0.5, 0.5), L(-3.5, 6.2, -1.6), OURO, forma="bola")
    escudo = L(3.6, 2.75, -1.5) @ rx(0.28) @ ry(math.pi / 2)
    parte(s, "AroEscudo", (0.3, 3.3, 3.3), escudo @ cf(-0.08, 0, 0), OURO, forma="cilindro")
    parte(s, "Escudo", (0.34, 2.9, 2.9), escudo, cor, forma="cilindro")
    parte(s, "Cruz", (0.38, 2.3, 0.4), escudo, clara)
    parte(s, "CruzLado", (0.38, 0.4, 1.7), escudo @ cf(0, 0.35, 0), clara)


def _mago(s, L, cor, clara):
    # cristais saindo de uma pedra (esquerda) e livros com uma vela (direita)
    parte(s, "PedraCristal", (2.2, 0.8, 1.9), L(-3.5, 1.5, -1.5) @ ry(0.4), (120, 108, 150))
    for dx, dz, alto, grosso, incl, tom in ((0, 0, 3.4, 0.9, 0.0, cor), (-0.6, 0.3, 2.3, 0.7, 0.35, clara),
                                              (0.6, -0.2, 1.8, 0.6, -0.4, clara), (0.2, 0.6, 1.5, 0.5, 0.2, cor)):
        parte(s, "Cristal", (grosso, alto, grosso), L(-3.5 + dx, 1.9 + alto / 2 * 0.9, -1.5 + dz) @ rz(incl) @ ry(math.pi / 4),
              tom, transp=0.05, refl=0.1)
    for i, (tom, giro) in enumerate((((150, 60, 70), 0.1), ((70, 80, 170), -0.25), ((60, 130, 90), 0.4))):
        parte(s, "Livro", (1.7, 0.36, 1.25), L(3.5, 1.3 + i * 0.37, -1.5) @ ry(giro), tom)
        parte(s, "Paginas", (1.55, 0.26, 1.15), L(3.5, 1.3 + i * 0.37, -1.5) @ ry(giro) @ cf(0.1, 0, 0), (246, 238, 214), colide=False)
    vx, _, vz = _ponto(L(3.5, 0, -1.5))
    coluna(s, "Vela", vx, 2.57, vz, 0.32, 0.7, (250, 240, 220))
    parte(s, "Chama", (0.22, 0.32, 0.22), cf(vx, 3.06, vz), (255, 200, 110), forma="bola", colide=False, sombra=False)


def _arqueiro(s, L, cor, clara, bib, giro):
    # alvo num cavalete (direita), aljava com flechas (esquerda) e uma bétula atrás
    for dx, incl in ((-0.95, -0.18), (0.95, 0.18)):
        parte(s, "PernaCavalete", (0.32, 4.4, 0.32), L(3.6 + dx, 3.1, -1.2) @ rz(incl), MADEIRA)
    parte(s, "PernaTras", (0.32, 4.4, 0.32), L(3.6, 3.0, -0.3) @ rx(-0.35), MADEIRA)
    alvo = L(3.6, 3.7, -1.45) @ rx(0.15) @ ry(math.pi / 2)
    for i, (diametro, tom) in enumerate(((3.2, (244, 240, 230)), (2.4, (222, 62, 72)), (1.6, (244, 240, 230)), (0.85, (255, 205, 70)))):
        parte(s, "Alvo", (0.3 + i * 0.04, diametro, diametro), alvo @ cf(i * 0.02, 0, 0), tom, forma="cilindro")
    for oy, oz in ((0.35, -0.3), (-0.5, 0.45)):
        flecha = alvo @ cf(0.6, oy, oz) @ ry(0.2)
        parte(s, "Flecha", (1.4, 0.12, 0.12), flecha, (196, 150, 96), colide=False)
        parte(s, "Pena", (0.45, 0.3, 0.06), flecha @ cf(0.55, 0, 0), clara, colide=False)
    aljava = L(-3.5, 2.4, -1.4) @ rz(0.18)
    parte(s, "Aljava", (2.4, 1, 1), aljava @ EM_PE, (150, 96, 58), forma="cilindro")
    parte(s, "AlcaAljava", (0.3, 1.05, 1.05), aljava @ cf(0, 0.5, 0) @ EM_PE, OURO, forma="cilindro")
    for dx, dz in ((-0.2, 0.15), (0.2, -0.1), (0.05, 0.25), (-0.1, -0.25)):
        parte(s, "Flecha", (0.12, 1.4, 0.12), aljava @ cf(dx, 1.75, dz), (196, 150, 96), colide=False)
        parte(s, "Pena", (0.06, 0.45, 0.3), aljava @ cf(dx, 2.3, dz), cor, colide=False)
    fx, _, fz = _ponto(L(6.5, 0, 8))
    bib.colocar(s, "BirchTree2", fx, fz, giro + 0.6, 0.95, cor={"Trunk": (238, 234, 224)})


def _assassino(s, L, cor, clara):
    # adagas cruzadas num toco (esquerda) e lanterna vermelha (direita)
    tx, _, tz = _ponto(L(-3.5, 0, -1.5))
    coluna(s, "Toco", tx, 1.8, tz, 1.7, 1.4, MADEIRA_ESCURA)
    for lado in (-1, 1):
        adaga = L(-3.5, 3.3, -1.5) @ rz(lado * 0.5)
        parte(s, "Lamina", (0.5, 2, 0.16), adaga, (70, 70, 84), refl=0.2, colide=False)
        parte(s, "Guarda", (1.1, 0.2, 0.26), adaga @ cf(0, 1.05, 0), cor, colide=False)
        parte(s, "Cabo", (0.24, 0.8, 0.24), adaga @ cf(0, 1.55, 0), (34, 28, 38), colide=False)
    parte(s, "Poste", (0.4, 6.4, 0.4), L(4.6, 4.3, -0.8), (40, 34, 46))
    parte(s, "Braco", (2, 0.3, 0.3), L(3.75, 7.3, -0.8), (40, 34, 46))
    parte(s, "Fio", (0.08, 0.8, 0.08), L(3, 6.75, -0.8), (40, 34, 46), colide=False)
    lanterna_vermelha = parte(s, "Lanterna", (1.4, 1.7, 1.4), L(3, 5.5, -0.8), (214, 44, 56), forma="bola", colide=False)
    for dy in (-0.82, 0.82):
        parte(s, "Tampa", (0.9, 0.26, 0.9), L(3, 5.5 + dy, -0.8), (40, 34, 46), colide=False)
    luz(lanterna_vermelha, "LuzChama", (255, 90, 80), 14, 1)


def construir_santuarios(raiz, bib, ordem, cores):
    """Um santuário por classe em meia-lua a oeste da praça, cada um virado para o centro:
    plataforma redonda com a cor da classe, arco de pedra com o emblema, estandartes e objetos do
    tema (Cavaleiro: espada na pedra e escudo; Mago: cristais e livros; Arqueiro: alvo e aljava;
    Assassino: adagas cruzadas e lanterna vermelha). A arma que gira e o prompt ficam no código,
    no marcador Altar_<classe> (em cima do pedestal)."""
    pasta_santuarios = pasta(raiz, "Santuarios")
    for classe, x, z, giro in santuarios(ordem):
        cor = cores[classe]
        escura = tuple(int(c * 0.5) for c in cor)
        clara = tuple(min(255, int(c + (255 - c) * 0.45)) for c in cor)
        s = modelo(pasta_santuarios, "Santuario_" + classe)
        base = cf(x, 0, z) @ ry(giro)

        def L(dx, dy, dz, base=base):
            return base @ cf(dx, dy, dz)

        # plataforma redonda: borda na cor da classe, pedra clara e um anel colorido no meio
        disco(s, "Borda", x, 0.35, z, 14, 0.7, cor)
        disco(s, "Plataforma", x, 0.55, z, 13, 1.1, PEDRA_CLARA)
        disco(s, "AnelClasse", x, 1.12, z, 8.6, 0.06, cor, colide=False, sombra=False)
        disco(s, "Miolo", x, 1.14, z, 7.6, 0.08, PEDRA_MIOLO, colide=False, sombra=False)
        parte(s, "Degrau", (5.5, 0.55, 2.4), L(0, 0.275, -7.2), PEDRA_MEDIA)
        # pedestal da arma
        px, _, pz = _ponto(L(0, 0, 0.8))
        coluna(s, "Pedestal", px, 2.2, pz, 2.6, 2.1, LILAS)
        coluna(s, "FaixaPedestal", px, 2.5, pz, 2.75, 0.35, cor, colide=False)
        coluna(s, "TopoPedestal", px, 3.4, pz, 3.3, 0.4, LILAS_CLARO)
        # arco de pedra no fundo
        for lado in (-1, 1):
            parte(s, "BasePilar", (2.3, 1, 2.3), L(lado * 4.8, 1.6, 3.6), LILAS_ESCURO)
            parte(s, "Pilar", (1.6, 10, 1.6), L(lado * 4.8, 6.1, 3.6), LILAS)
            parte(s, "Capitel", (2.1, 0.6, 2.1), L(lado * 4.8, 11.4, 3.6), LILAS_CLARO)
            # estandarte da classe pendurado na frente do pilar, com a ponta em V
            parte(s, "Estandarte", (2.4, 5.6, 0.2), L(lado * 4.8, 7.4, 2.65), escura, colide=False)
            parte(s, "FaixaEstandarte", (2.5, 0.4, 0.26), L(lado * 4.8, 9.95, 2.62), OURO, colide=False)
            parte(s, "SimboloEstandarte", (0.9, 0.9, 0.26), L(lado * 4.8, 7.6, 2.6) @ rz(math.pi / 4), clara, colide=False)
            parte(s, "PontaEstandarte", (1.7, 1.7, 0.2), L(lado * 4.8, 4.6, 2.65) @ rz(math.pi / 4), escura, colide=False)
        segmentos = 9
        for k in range(segmentos):
            angulo = math.pi * k / (segmentos - 1)
            parte(s, "Arco", (1.7, 2 * 4.8 * math.sin(math.pi / (2 * (segmentos - 1))) + 0.55, 1.7),
                  L(4.8 * math.cos(angulo), 11.7 + 4.8 * math.sin(angulo), 3.6) @ rz(angulo),
                  LILAS_CLARO if k % 2 == 0 else LILAS)
        # emblema da classe no alto do arco
        parte(s, "MolduraEmblema", (2.7, 2.7, 0.3), L(0, 16.5, 2.62) @ rz(math.pi / 4), OURO, colide=False)
        parte(s, "Emblema", (2, 2, 0.32), L(0, 16.5, 2.5) @ rz(math.pi / 4), cor, colide=False)
        parte(s, "PontaEmblema", (0.9, 0.9, 0.9), L(0, 18.6, 3.6), OURO, forma="bola")
        # objetos do tema
        if classe == "cavaleiro":
            _cavaleiro(s, L, cor, clara)
        elif classe == "mago":
            _mago(s, L, cor, clara)
        elif classe == "arqueiro":
            _arqueiro(s, L, cor, clara, bib, giro)
        elif classe == "assassino":
            _assassino(s, L, cor, clara)
        # flores na cor da classe, dos dois lados da frente
        for lado in (-1, 1):
            for _ in range(5):
                fx, _, fz = _ponto(L(lado * rng.uniform(7.4, 9), 0, rng.uniform(-5, -1)))
                altura = rng.uniform(0.6, 1.1)
                parte(s, "Talo", (0.14, altura, 0.14), cf(fx, altura / 2, fz), (84, 168, 58), colide=False, sombra=False)
                parte(s, "Flor", (0.7, 0.5, 0.7), cf(fx, altura + 0.1, fz), clara, forma="bola", colide=False, sombra=False)
    return pasta_santuarios


def construir_loja(raiz):
    loja = pasta(raiz, "Loja")
    x, z = 42, 0
    parte(loja, "Chao", (14, 0.6, 12), cf(x, 0.3, z), MADEIRA_CLARA)
    for dx in (-6, 6):
        for dz in (-5, 5):
            parte(loja, "Poste", (0.7, 11, 0.7), cf(x + dx, 5.5, z + dz), MADEIRA)
    # toldo listrado em duas águas (vermelho e creme)
    faixas = 5
    largura = 14.5 / faixas
    for lado in (-1, 1):
        for i in range(faixas):
            dx = -14.5 / 2 + largura * (i + 0.5)
            cor = VERMELHO_LONA if i % 2 == 0 else CREME_LONA
            giro = math.pi if lado == 1 else 0.0
            parte(loja, "Toldo", (largura, 4, 6.5), cf(x + dx, 13, z + lado * 3.25) @ ry(giro), cor, classe="WedgePart")
    parte(loja, "Balcao", (3, 3.5, 10), cf(x - 5, 2.35, z), (186, 130, 80))
    parte(loja, "Tampo", (3.6, 0.4, 10.6), cf(x - 5, 4.3, z), MADEIRA_ESCURA)
    for dz in (-3, -1.5, 2.5):
        parte(loja, "Moeda", (0.2, 0.9, 0.9), cf(x - 5, 4.6, z + dz) @ EM_PE, (255, 205, 60), forma="cilindro", colide=False, refl=0.2)
    pocao = parte(loja, "Pocao", (0.9, 0.9, 0.9), cf(x - 5, 5, z + 0.5), (255, 90, 150), forma="bola", colide=False, transp=0.15)
    luz(pocao, "Luz", (255, 80, 120), 8, 1)
    # mercador encapuzado
    capa = (96, 70, 150)
    parte(loja, "Corpo", (2.4, 4.6, 1.8), cf(x - 1, 2.9, z), capa)
    parte(loja, "Capuz", (2, 2, 2), cf(x - 1, 6, z), (76, 54, 120))
    parte(loja, "Rosto", (0.2, 1.3, 1.5), cf(x - 2, 5.9, z), (20, 14, 30))
    for dz in (-0.35, 0.35):
        olho = parte(loja, "Olho", (0.15, 0.22, 0.3), cf(x - 2.12, 6.05, z + dz), (255, 210, 90), material="Neon", colide=False)
        luz(olho, "Luz", (255, 210, 90), 4, 0.6)
    lanterna(loja, x - 7, z + 6)
    lanterna(loja, x - 7, z - 6)
    return loja


def construir_placa(raiz):
    placa = pasta(raiz, "Placa")
    base = cf(16, 0, 30) @ ry(math.radians(20))
    parte(placa, "QuadroComoJogar", (14, 9, 0.8), base @ cf(0, 6, 0), MADEIRA_CLARA)
    parte(placa, "Moldura", (14.8, 9.8, 0.6), base @ cf(0, 6, 0.15), MADEIRA_ESCURA)
    for dx in (-6, 6):
        parte(placa, "Pe", (0.8, 6, 0.8), base @ cf(dx, 2, 0), MADEIRA)
    parte(placa, "Telhadinho", (15.6, 0.6, 2), base @ cf(0, 10.8, 0), VERMELHO_LONA)
    return placa


def construir_lago(raiz, bib):
    """Lago de verdade: um buraco no chão (chao_com_buraco) com margem de areia descendo até o
    fundo. A peça azul "Agua" é só o lugar da água: no jogo, server/Lobby.luau enche esse volume
    com água do Terrain (com ondas e reflexo, dá para nadar) e some com a peça."""
    lago = pasta(raiz, "Lago")
    lx, lz = LAGO
    raio = RAIO_LAGO
    corrida = 6.0  # quanto a margem anda para dentro até chegar ao fundo
    # margem: anel de cunhas com a parte alta para fora (no nível do chão) e a rampa para o meio
    n = 44
    for i in range(n):
        a = i / n * math.tau
        r = raio - corrida / 2
        parte(lago, "Margem", (2 * math.pi * raio / n * 1.12, -FUNDO_LAGO, corrida),
              cf(lx + math.cos(a) * r, FUNDO_LAGO / 2, lz + math.sin(a) * r) @ ry(math.atan2(math.cos(a), math.sin(a))),
              (206, 176, 120), classe="WedgePart")
    # praia de areia por cima da borda (cobre os degrauzinhos do chão)
    n = 48
    dentro, fora = raio - 0.4, PRAIA
    for i in range(n):
        a = i / n * math.tau
        r = (dentro + fora) / 2
        parte(lago, "Praia", (2 * math.pi * fora / n * 1.06, 0.16, fora - dentro),
              cf(lx + math.cos(a) * r, 0.08, lz + math.sin(a) * r) @ ry(math.atan2(math.cos(a), math.sin(a))), TERRA)
    # fundo de areia, mais escuro no meio (parece mais fundo através da água)
    disco(lago, "Fundo", lx, FUNDO_LAGO - 0.5, lz, 2 * (raio - 2.5), 1, (214, 192, 140))
    disco(lago, "FundoMeio", lx, FUNDO_LAGO + 0.03, lz, 2 * (raio - 9), 0.1, (88, 160, 150), colide=False, sombra=False)
    disco(lago, "Agua", lx, (NIVEL_AGUA + FUNDO_LAGO) / 2, lz, 2 * raio, NIVEL_AGUA - FUNDO_LAGO, AGUA,
          colide=False, sombra=False, transp=0.45)
    pedras = ["Rock1", "Rock2", "Rock3", "Rock4", "Rock5", "Rock6", "Rock7", "Rock8", "Rock9", "Rock10"]
    for _ in range(6):  # pedras no fundo
        b, d = rng.uniform(0, math.tau), rng.uniform(2, raio - 8)
        bib.colocar(lago, rng.choice(pedras), lx + math.cos(b) * d, lz + math.sin(b) * d, rng.uniform(0, math.tau),
                    rng.uniform(0.25, 0.45), y=FUNDO_LAGO - 0.2)

    # píer de madeira saindo do caminho que vem da praça
    a = math.atan2(46 - lz, 58 - lx)
    giro_pier = math.atan2(math.cos(a), math.sin(a))
    pier = cf(lx, 0, lz) @ ry(giro_pier)  # +Z local aponta para fora do lago, na direção do caminho
    perto, longe = 10.5, PRAIA - 0.6
    tabuas = int((longe - perto) / 1.0)
    for i in range(tabuas):
        r = perto + (i + 0.5) * (longe - perto) / tabuas
        parte(lago, "Tabua", (4.4, 0.3, 0.9), pier @ cf(0, 0.55, r) @ ry(rng.uniform(-0.03, 0.03)),
              MADEIRA_CLARA if i % 2 == 0 else (206, 150, 96))
    for lado in (-1, 1):
        parte(lago, "Viga", (0.5, 0.5, longe - perto + 0.6), pier @ cf(lado * 1.9, 0.2, (perto + longe) / 2), MADEIRA)
        for r in (perto + 0.4, perto + 4.5, perto + 8.6):
            x, _, z = _ponto(pier @ cf(lado * 2.05, 0, r))
            coluna(lago, "Estaca", x, (FUNDO_LAGO + 1.1) / 2, z, 0.62, 1.1 - FUNDO_LAGO, MADEIRA_ESCURA)
    x, _, z = _ponto(pier @ cf(1.6, 0, perto + 0.6))
    lanterna(lago, x, z, giro_pier + math.pi / 2)

    # vitórias-régias boiando, algumas com flor
    for i in range(10):
        b = rng.uniform(0, math.tau)
        if abs(math.remainder(b - a, math.tau)) < 0.35:
            continue  # longe do píer
        d = rng.uniform(4, raio - 6)
        fx, fz = lx + math.cos(b) * d, lz + math.sin(b) * d
        disco(lago, "FolhaDeLirio", fx, NIVEL_AGUA + 0.06, fz, rng.uniform(1.8, 2.8), 0.1, (96, 196, 72), colide=False, sombra=False)
        if i % 3 == 0:
            parte(lago, "FlorDeLirio", (0.8, 0.5, 0.8), cf(fx + 0.3, NIVEL_AGUA + 0.32, fz), (255, 160, 210), forma="bola", colide=False, sombra=False)
    # taboas na beira da água
    for i in range(7):
        b = i / 7 * math.tau + rng.uniform(-0.2, 0.2)
        if abs(math.remainder(b - a, math.tau)) < 0.5:
            continue
        for _ in range(rng.randint(3, 5)):
            d = rng.uniform(raio - 3.2, raio - 1.6)
            tx, tz = lx + math.cos(b) * d + rng.uniform(-1, 1), lz + math.sin(b) * d + rng.uniform(-1, 1)
            altura = rng.uniform(3, 4.4)
            topo = NIVEL_AGUA + altura - 1.4
            parte(lago, "Taboa", (0.16, altura, 0.16), cf(tx, topo - altura / 2, tz) @ rz(rng.uniform(-0.12, 0.12)), (74, 150, 60), colide=False)
            parte(lago, "Espiga", (0.42, 1, 0.42), cf(tx, topo - 0.3, tz), (140, 86, 52), forma="bola", colide=False)
    # pedras e plantas em volta
    for i in range(16):
        b = i / 16 * math.tau + rng.uniform(-0.12, 0.12)
        if abs(math.remainder(b - a, math.tau)) < 0.25:
            continue
        bib.colocar(lago, rng.choice(pedras), lx + math.cos(b) * (PRAIA + 0.4), lz + math.sin(b) * (PRAIA + 0.4),
                    rng.uniform(0, math.tau), rng.uniform(0.22, 0.38), y=-0.3)
    for i in range(16):
        b = rng.uniform(0, math.tau)
        if abs(math.remainder(b - a, math.tau)) < 0.3:
            continue
        d = PRAIA + rng.uniform(2, 4.5)
        bib.colocar(lago, rng.choice(["Fern1", "Fern2", "Grass1", "Grass2", "Grass3"]), lx + math.cos(b) * d, lz + math.sin(b) * d,
                    rng.uniform(0, math.tau), rng.uniform(1.2, 1.8), colide=False, sombra=False)
    return lago


def ponto_livre(raio_min, raio_max, folga=0.0, tentativas=60):
    for _ in range(tentativas):
        angulo = rng.uniform(0, math.tau)
        d = math.sqrt(rng.uniform(raio_min ** 2, raio_max ** 2))
        x, z = math.cos(angulo) * d, math.sin(angulo) * d
        if livre(x, z, folga):
            return x, z
    return None


def construir_natureza(raiz, bib):
    natureza = pasta(raiz, "Natureza")
    arvores = pasta(natureza, "Arvores")
    galhadas = ["Tree1", "Tree2", "Tree3", "TallTree1", "TallTree2"]
    betulas = ["BirchTree1", "BirchTree2", "BrichTree3", "BirchTree4"]
    pinheiros = ["PineTree1", "PineTree2", "PineTree3", "PineTree4", "TallerPineTree1", "TallerPineTree2", "TallerPineTree3", "TallerPineTree4"]
    tronco_betula = {"Trunk": (238, 234, 224)}
    posicoes = []

    def plantar(x, z, grande=False):
        sorteio = rng.random()
        if grande and sorteio < 0.25:
            nome, escala, cor = rng.choice(["JungleTree1", "JungleTree2"]), rng.uniform(0.7, 0.85), None
        elif sorteio < 0.5:
            nome, escala, cor = rng.choice(galhadas), rng.uniform(0.9, 1.3), None
        elif sorteio < 0.75:
            nome, escala, cor = rng.choice(betulas), rng.uniform(0.85, 1.15), tronco_betula
        else:
            nome, escala, cor = rng.choice(pinheiros), rng.uniform(0.75, 1.05), None
        bib.colocar(arvores, nome, x, z, rng.uniform(0, math.tau), escala, cor=cor)
        posicoes.append((x, z))

    # anel de floresta em volta do acampamento (mais fechado no fundo)
    tentativas = 0
    while len(posicoes) < 62 and tentativas < 4000:
        tentativas += 1
        p = ponto_livre(52, 112, folga=4)
        if p and all(math.hypot(p[0] - a, p[1] - b) > 13 for a, b in posicoes):
            plantar(p[0], p[1], grande=math.hypot(*p) > 92)
    # algumas árvores mais perto, enfeitando os caminhos
    for x, z in ((-22, 44), (-60, 48), (60, -30), (-26, -48)):
        if livre(x, z, 2):
            plantar(x, z)

    # cogumelos: grupinhos perto das árvores e alguns gigantes (marcos do acampamento)
    cogumelos = pasta(natureza, "Cogumelos")
    for x, z in rng.sample(posicoes, 26):
        angulo = rng.uniform(0, math.tau)
        bib.colocar(cogumelos, rng.choice(["MushroomCluster1", "MushroomCluster2", "MushroomCluster3"]),
                    x + math.cos(angulo) * 5, z + math.sin(angulo) * 5, rng.uniform(0, math.tau), rng.uniform(1.6, 2.6), colide=False)
    for x, z, escala in ((56, 18, 4.2), (88, 40, 3.4), (60, 78, 3.8), (-70, 62, 4.4), (-82, -40, 3.6), (30, 60, 3.0)):
        if livre(x, z, 0, lago=True):
            bib.colocar(cogumelos, "LargeMushroon", x, z, rng.uniform(0, math.tau), escala)

    # samambaias, grama alta, gravetos e troncos caídos
    rasteiras = pasta(natureza, "Rasteiras")
    for x, z in rng.sample(posicoes, 40):
        angulo = rng.uniform(0, math.tau)
        bib.colocar(rasteiras, rng.choice(["Fern1", "Fern2", "Fern3"]), x + math.cos(angulo) * 7, z + math.sin(angulo) * 7,
                    rng.uniform(0, math.tau), rng.uniform(1.1, 1.7), colide=False)
    # grama alta: muitos tufos, em grupinhos
    grama = pasta(natureza, "Grama")
    for _ in range(190):
        p = ponto_livre(34, 110, folga=0.5)
        if not p:
            continue
        for _ in range(rng.randint(3, 6)):
            gx, gz = p[0] + rng.uniform(-3, 3), p[1] + rng.uniform(-3, 3)
            if livre(gx, gz):
                bib.colocar(grama, rng.choice(["Grass1", "Grass2", "Grass3"]), gx, gz, rng.uniform(0, math.tau),
                            rng.uniform(1.2, 2.2), colide=False, sombra=False)
    for x, z in rng.sample(posicoes, 12):
        bib.colocar(rasteiras, rng.choice(["StickCluster", "Stick1", "Stick2"]), x + 4, z - 3, rng.uniform(0, math.tau), 1.6, colide=False)
    for x, z, giro in ((22, 34, 0.3), (9, 38, 1.4), (-64, 30, 0.8)):
        bib.colocar(rasteiras, "FallenLog", x, z, giro, 1.3)
    bib.colocar(rasteiras, "LargeHollowLog", -96, 70, 0.9, 0.7)

    # pedras: grupinhos pelo campo e paredões grandes atrás das colinas
    pedras = pasta(natureza, "Pedras")
    nomes_pedras = ["Rock1", "Rock2", "Rock3", "Rock4", "Rock5", "Rock6", "Rock7", "Rock8", "Rock9", "Rock10"]
    for _ in range(22):
        p = ponto_livre(40, 108, folga=3)
        if p:
            bib.colocar(pedras, rng.choice(nomes_pedras), p[0], p[1], rng.uniform(0, math.tau), rng.uniform(0.35, 0.8))
    for i in range(14):
        angulo = i / 14 * math.tau + rng.uniform(-0.1, 0.1)
        d = rng.uniform(124, 138)
        if math.hypot(math.cos(angulo) * d - LAGO[0], math.sin(angulo) * d - LAGO[1]) < PRAIA + 24:
            continue  # longe do lago
        bib.colocar(pedras, rng.choice(["LargeRock1", "LargeRock2", "LargeRock3"]), math.cos(angulo) * d, math.sin(angulo) * d,
                    rng.uniform(0, math.tau), rng.uniform(1.4, 2.1), y=-2)

    # flores coloridas em tufos
    flores = pasta(natureza, "Flores")
    for _ in range(70):
        p = ponto_livre(34, 104, folga=1)
        if not p:
            continue
        tufo = modelo(flores, "Flores")
        cor = rng.choice(FLORES)
        for _ in range(rng.randint(3, 6)):
            fx, fz = p[0] + rng.uniform(-1.6, 1.6), p[1] + rng.uniform(-1.6, 1.6)
            altura = rng.uniform(0.7, 1.3)
            parte(tufo, "Talo", (0.14, altura, 0.14), cf(fx, altura / 2, fz), (84, 168, 58), colide=False, sombra=False)
            parte(tufo, "Flor", (0.75, 0.55, 0.75), cf(fx, altura + 0.1, fz), cor, forma="bola", colide=False, sombra=False)
            parte(tufo, "Miolo", (0.3, 0.3, 0.3), cf(fx, altura + 0.32, fz), (255, 214, 80), forma="bola", colide=False, sombra=False)
    return natureza


def construir_decoracao(raiz):
    deco = pasta(raiz, "Decoracao")
    for x, z in ((-6, -14), (6, -14), (-6, -34), (6, -34), (-18, 6), (18, 6), (-6, 40), (6, 52)):
        lanterna(deco, x, z)
    # cercas de madeira (amarelas, como na referência)
    cerca(deco, -5.5, 32, -5.5, 56)
    cerca(deco, 5.5, 32, 5.5, 56)
    return deco


def construir_limites(raiz):
    limites = pasta(raiz, "Limites")
    for tamanho, posicao in (((240, 60, 2), (0, 30, 118)), ((240, 60, 2), (0, 30, -118)),
                             ((2, 60, 240), (118, 30, 0)), ((2, 60, 240), (-118, 30, 0))):
        parte(limites, "Limite", tamanho, cf(*posicao), (255, 255, 255), transp=1, sombra=False)


def construir_marcadores(raiz, ordem):
    m = pasta(raiz, "Marcadores")
    marcador(m, "Nascimento", 0, 0.5, 22, (10, 1, 6))
    marcador(m, "Portal", POSICAO_PORTAL[0], 0.5, POSICAO_PORTAL[1], (18, 1, 18))
    marcador(m, "Vortice", 0, 11, -60, (2, 2, 2))
    marcador(m, "Cristal", 0, 16, 0, (1, 1, 1))
    for classe, x, z, giro in santuarios(ordem):
        # em cima do pedestal e virado para a praça (a arma flutua acima dele)
        altar = marcador(m, "Altar_" + classe, 0, 0, 0, (1, 1, 1))
        props = altar.find("Properties")
        props.remove(props.find("./CoordinateFrame[@name='CFrame']"))
        p_cframe(props, "CFrame", cf(x, 0, z) @ ry(giro) @ cf(0, 3.6, 0.8))
    marcador(m, "PlacaAltares", -60, 23, 0, (1, 1, 1))
    marcador(m, "Loja", 37, 4.6, 0, (1, 1, 1))
    marcador(m, "Vagalumes", 0, 7, 0, (3, 3, 3))  # centro da área dos vagalumes (200 x 200)
    return m


def previa(raiz):
    """Desenho visto de cima (para conferir sem abrir o Studio)."""
    from PIL import Image, ImageDraw
    escala, meio = 4, 480
    img = Image.new("RGB", (meio * 2, meio * 2), (30, 30, 36))
    d = ImageDraw.Draw(img)
    pecas = []
    for item in raiz.iter("Item"):
        if item.get("class") not in ("Part", "MeshPart", "WedgePart"):
            continue
        props = item.find("Properties")
        e = props.find("./CoordinateFrame[@name='CFrame']")
        tam = props.find("./Vector3[@name='size']")
        transp = props.find("./float[@name='Transparency']")
        if transp is not None and float(transp.text) >= 1:
            continue
        x, y, z = (float(e.find(k).text) for k in "XYZ")
        sx, sy, sz = (float(c.text) for c in tam)
        r = np.array([[float(e.find(f"R{i}{j}").text) for j in range(3)] for i in range(3)])
        meio_ext = np.abs(r) @ np.array([sx, sy, sz]) / 2
        cor8 = props.find("./Color3uint8[@name='Color3uint8']")
        valor = int(cor8.text) if cor8 is not None else 0xFFAAAAAA
        cor = ((valor >> 16) & 255, (valor >> 8) & 255, valor & 255)
        if cor == (255, 80, 200):
            continue  # marcadores
        forma = props.find("./token[@name='shape']")
        redondo = item.get("class") == "MeshPart" or (forma is not None and forma.text in ("0", "2"))
        pecas.append((y + meio_ext[1], x, z, meio_ext[0], meio_ext[2], cor, redondo))
    for _, x, z, hx, hz, cor, redondo in sorted(pecas):
        caixa = [meio + (x - hx) * escala, meio + (z - hz) * escala, meio + (x + hx) * escala, meio + (z + hz) * escala]
        if redondo:
            d.ellipse(caixa, fill=cor, outline=tuple(int(c * 0.8) for c in cor))
        else:
            d.rectangle(caixa, fill=cor)
    d.text((10, 10), "Lobby visto de cima (portal em cima, lago embaixo à direita)", fill=(255, 255, 255))
    img.save(PREVIA)


def main():
    ordem, cores = cores_das_classes()
    bib = Biblioteca(BIBLIOTECA)
    documento = ET.Element("roblox", {"version": "4"})
    raiz = modelo(documento, "Lobby")
    construir_chao(raiz)
    construir_praca(raiz)
    construir_portal(raiz)
    construir_santuarios(raiz, bib, ordem, cores)
    construir_loja(raiz)
    construir_placa(raiz)
    construir_lago(raiz, bib)
    construir_decoracao(raiz)
    construir_natureza(raiz, bib)
    construir_limites(raiz)
    construir_marcadores(raiz, ordem)
    if bib.usados:
        bloco = ET.SubElement(documento, "SharedStrings")
        for md5 in sorted(bib.usados):
            ET.SubElement(bloco, "SharedString", {"md5": md5}).text = bib.compartilhados.get(md5, "")
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    ET.ElementTree(documento).write(SAIDA, encoding="utf-8")
    pecas = sum(1 for i in raiz.iter("Item") if i.get("class") in ("Part", "MeshPart", "WedgePart"))
    print(f"Lobby gerado: {SAIDA} ({pecas} peças, {os.path.getsize(SAIDA) // 1024} KB)")
    previa(raiz)
    print("Prévia:", PREVIA)


if __name__ == "__main__":
    main()
