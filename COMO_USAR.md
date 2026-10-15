# Masmorra das Cartas

Roguelike cooperativo para Roblox, de 1 a 4 jogadores, inspirado em Ember Knights e Warcraft. Escolha entre **Cavaleiro**, **Mago**, **Arqueiro** e **Assassino** e desça por salas sorteadas. Use combos, esquiva e supremos, e monte sua build com cartas próprias da sua classe. A cada 5 salas vem um chefe, e depois dele você decide: **subir e guardar o ouro** ou **descer mais fundo**.

## Abrir e jogar

1. Instale o [Roblox Studio](https://create.roblox.com/).
2. Dê dois cliques em `MasmorraDasCartas.rbxlx` (ou, no Studio, use **File > Open from File**).
3. Clique em **Play** (F5).

Tudo é criado por código quando o jogo começa (terreno, salas, monstros, interface). Por isso, no modo de edição, o mundo aparece vazio.

**Testar em grupo no Studio:** aba **Test > Clients and Servers**, escolha 2 jogadores e clique em **Start**.

## Controles

| Ação | Computador | Celular | Controle |
|---|---|---|---|
| Atacar (combo de 3) | Clique esquerdo (mira no mouse) | Botão ⚔️ (mira sozinho) | R2 |
| Golpe carregado | Segurar e soltar o clique esquerdo | Segurar e soltar ⚔️ | Segurar e soltar R2 |
| Habilidade | E | Botão de cima | X |
| Esquiva | Q | Botão 💨 | B |
| Supremo | R (com a barra dourada cheia) | Botão do topo | Y |
| Defender com o escudo (Cavaleiro) | Segurar F ou o botão direito | Segurar 🛡️ | Segurar L2 |

Essas são as teclas padrão. Para trocar, use o botão **⚙️ TECLAS** no acampamento ou a engrenagem ao lado da barra de ações durante a partida. Cada ação aceita uma tecla principal e uma alternativa (tecla ou botão do mouse), e a escolha fica salva no seu perfil. W, A, S, D, Espaço, Esc e Tab ficam reservadas para o Roblox.

## As classes

| Classe | Estilo | Ponto forte | Ponto fraco | Habilidade (E) | Supremo (R) |
|---|---|---|---|---|---|
| 🛡️ Cavaleiro | Espada e escudo, tanque, atrai os inimigos | Muita vida e armadura, defende com o escudo | Lento, esquiva demora mais, só bate de perto | Redemoinho (tornado que puxa os inimigos; recebe 40% menos dano) | Julgamento (espada de luz do céu: atordoa e dá escudo aos aliados) |
| 🔮 Mago | Cajado e magias diferentes a cada golpe | Dano em área, fogo, gelo e arcano | Pouca vida, ataque lento, depende de mana | Meteoro (gasta mana; deixa o chão em chamas) | Tempestade Arcana (nuvem com raios que deixam lento) |
| 🏹 Arqueiro | Tira cada flecha da aljava e atira de longe | Maior alcance, muito ágil, flechas fortes | Flechas perdem força em inimigos colados | Chuva de Flechas (salta para trás antes) | Saraivada (vendaval em volta; corre 30% mais rápido) |
| 🗡️ Assassino | Duas adagas, sangramento, golpes pelas costas | O mais rápido, críticos, faz sangrar | Defesa baixa (leva 15% a mais de dano), pouca vida | Passo Sombrio (aparece atrás do alvo com crítico garantido) | Lâminas da Noite (intocável, salta entre até 10 inimigos) |

**Escudo (Cavaleiro):** andando, o escudo vai solto ao lado do corpo; segurando a defesa, ele vem para o centro do peito (com o ombro esquerdo à frente), dá um estouro de energia e fica brilhando enquanto a defesa está ativa. Golpes vindos da frente perdem 75% do dano. Erguendo o escudo logo antes do golpe (até 0,3s), é uma **defesa perfeita**: não leva dano nenhum, dá um empurrão com o escudo e atordoa quem atacou. Com o escudo erguido o Cavaleiro anda devagar e não ataca.

**Golpes do Cavaleiro:** no combo, o quadril e o tronco torcem junto com a espada. O 1º golpe corta da direita para a esquerda, o 2º é um revés da esquerda para a direita e o 3º é um **giro de 360°** que acerta tudo em volta. Segurando o ataque, ele ergue a espada e gira ela acima da cabeça, com um círculo mágico no chão e vento em volta (fica dourado com a carga cheia). Ao soltar, ele bate a espada no chão e lança um **tornado** que anda para a frente puxando e ferindo os inimigos. Com a carga cheia, o tornado explode no fim e atordoa. A habilidade (E) é uma **tempestade de cortes** em volta dele. O supremo (R) faz cair um **raio** com uma explosão dourada e, por **10 segundos**, o Cavaleiro fica **brilhando** (azul e dourado) e recebe **10% menos dano**. Com uma carta de fogo (Fúria do Dragão ou Redemoinho Flamejante), **a lâmina pega fogo** e os cortes, o tornado e a habilidade ficam **de fogo** e queimam. A esquiva dele é um **rolamento** para a frente (um pouco mais lento que o das outras classes, mas cobre a mesma distância e fica invulnerável durante o rolamento inteiro).

**Mago levitando:** o Mago flutua o tempo todo (parado, atacando e conjurando), com as pernas soltas e um anel de energia roxo no chão; andando, ele desliza no ar inclinado para onde vai. A esquiva é um portal (some e aparece). Explosões, meteoro e tempestade causam **15% a mais de dano em área** (`danoEmArea` em Classes.luau). Todas as magias usam efeitos dos pacotes de VFX (veja a tabela em `vfx/LEIA-ME.md`).

**Arqueiro (verde):** anda com passos leves e rápidos de caçador, o arco baixo na mão esquerda. Cada tiro tira a flecha da aljava, encaixa, puxa até o rosto e solta com um anel de vento verde no arco; as flechas voam com um rastro de vento verde e estouram em verde no inimigo. O 3º tiro e o tiro carregado saem com uma rajada forte; carregando, a energia junta na ponta da flecha e brilha quando a carga enche. A **Chuva de Flechas** (E) abre um portal verde no céu e as flechas caem e ficam cravadas no chão. A **Saraivada** (R) solta um estouro verde e um redemoinho de vento acompanha o Arqueiro enquanto ele atira para todos os lados. A esquiva solta riscos de velocidade e vento. Com a carta **Flechas de Fogo**, a flecha no arco vira brasa e os disparos, as flechas e os impactos ficam **de fogo**.

**Mana (Mago):** toda magia gasta mana, que volta sozinha com o tempo e enche ao entrar numa sala nova. O combo é Dardo Arcano → Lança de Gelo (deixa lento) → Bola de Fogo (explode e queima), e o golpe carregado é o Orbe do Vazio, que puxa os inimigos enquanto voa. Cartas como Fonte Arcana, Reservatório Arcano, Sifão de Almas e Mente Serena ajudam na mana.

**Sangramento (Assassino):** cada golpe abre um corte e o inimigo sangra por 4 segundos, acumulando até 5 vezes.

**Assassino (carmesim e preto):** corre baixo como um ninja, com as adagas para trás. Os golpes soltam cortes vermelhos no ar (sem rastro branco nas lâminas), o 3º golpe crava um X de cortes no chão, e cada acerto espirra sangue escuro; críticos e golpes pelas costas estouram mais forte. Carregando, a escuridão se junta em volta dele e um selo vermelho acende no chão quando enche; a **Investida Letal** deixa riscos escuros no caminho e termina numa explosão vermelha e preta. O **Passo Sombrio** (E) some e aparece numa fumaça escura. Nas **Lâminas da Noite** (R) os **olhos dele acendem em vermelho** enquanto ele salta de inimigo em inimigo.

**Golpe carregado** (segure o ataque e solte): Cavaleiro lança um tornado, Mago lança o Orbe do Vazio, Arqueiro dispara uma flecha perfurante e Assassino avança cortando tudo numa linha (Investida Letal).

**Pelas costas:** o Assassino causa +50% de dano acertando o inimigo por trás. Funciona muito bem junto com o Cavaleiro, que atrai a atenção.

O Cavaleiro, o Arqueiro e o Assassino têm um **andar próprio** (o Cavaleiro com passada firme, escudo do lado esquerdo e espada na mão direita; o Arqueiro com passos curtos e ágeis; o Assassino numa corrida baixa de ninja), que substitui a animação de andar do avatar do jogador; o Mago desliza no ar. Cada classe também tem uma **pose própria** parada: o Cavaleiro em guarda, o Mago ereto conjurando luz, o Arqueiro relaxado olhando em volta e o Assassino agachado e inclinado.

Cada classe tem pelo menos **11 cartas próprias** (o Mago tem 15, com as de mana), e existem **11 cartas universais**.

## Mecânicas

- **Combo:** todo terceiro ataque é um golpe final mais forte.
- **Esquiva:** você fica invulnerável por um instante e atravessa projéteis.
- **Avisos no chão:** áreas vermelhas mostram onde o golpe do inimigo vai cair. O círculo de dentro enche até a hora do golpe.
- **Caído e reviver:** quem perde toda a vida cai. Um aliado precisa ficar perto por 3 segundos para levantar quem caiu. Sem ajuda em 15 segundos, a pessoa só volta quando a sala for limpa.
- **Ameaça:** os inimigos atacam quem causa mais dano. O Cavaleiro chama o dobro de atenção, então ele funciona como o tanque do grupo.
- **Elites:** inimigos com ★ e um poder (Blindado, Veloz, Gélido, Explosivo, Gigante). Dão 3x mais ouro.
- **Temas e chefes:** Calabouço (Rei Esqueleto), Caverna (Rainha Aranha), Cripta (Lich Gélido) e Fornalha (Senhor das Chamas). Os chefes têm uma segunda fase com metade da vida.

## Efeitos sonoros

O jogo tem 38 efeitos sonoros (cortes, flechas, magias, escudo, impactos, explosões, moedas, interface...). Eles foram **criados do zero por síntese** pelo script `ferramentas/gerar_sons.py` e ficam todos juntos em um arquivo só: `sons/MasmorraSons.ogg`. O Roblox não deixa colocar áudio dentro do arquivo `.rbxlx`, então é preciso enviar esse arquivo **uma vez**:

1. No Roblox Studio, abra **Window > Asset Manager** (ou **View > Asset Manager**) e clique em **Bulk Import**. Também dá pelo site: **create.roblox.com > Creations > Audio > Upload Asset**.
2. Escolha `sons/MasmorraSons.ogg` e confirme. Espere a moderação aprovar (costuma levar poucos minutos).
3. Copie o ID do áudio (no Asset Manager: botão direito > **Copy Asset ID**).
4. Em `src/shared/Config.luau`, cole o ID: `Config.SONS_ID = "rbxassetid://SEU_ID_AQUI"`.
5. Rode `py build.py` de novo e abra o `MasmorraDasCartas.rbxlx` (ou faça a mesma troca direto no Studio, em **ReplicatedStorage > Shared > Config**).

Envie o áudio pela **mesma conta (ou grupo) dona do jogo**; áudio de outra conta não toca. Enquanto o ID não for colocado, só as explosões têm som (um som que já vem com o Roblox) e aparece um aviso na janela Output.

Se preferir enviar os sons um por um, eles também estão separados em `sons/individuais/`; coloque cada ID em `Config.SONS_IDS` (por exemplo `espada = "rbxassetid://..."`). Para mudar um som, edite `ferramentas/gerar_sons.py` e rode `py ferramentas/gerar_sons.py` (precisa de `pip install numpy scipy` e do ffmpeg); depois envie o arquivo novo.

## Segurança: pacotes do Toolbox

Pacotes grátis de efeitos e armas às vezes trazem **scripts escondidos** (dentro de partículas, de bonecos de exibição...). Já apareceram dois tipos neste projeto:
- **Backdoor:** baixa código de outra pessoa com `require(número)` e dá a ela controle do jogo.
- **Golpe no Studio:** só roda no Studio, mostra uma janela falsa pedindo para você copiar um código e colar na Command Bar.

**Nunca cole na Command Bar um código que uma janela "pediu".** Efeitos não precisam de script: antes de usar um pacote, procure Script/LocalScript dentro dele e apague. O `build.py` remove scripts de tudo que está em `vfx/` e `modelos/`.

## Efeitos do plugin (VFX Studio ou outro)

Dá para trocar ou reforçar os efeitos do Cavaleiro por efeitos montados no Studio com um plugin como o **VFX Studio**. Eles usam texturas que já estão no Roblox, então não precisa enviar nada. O jogo toca cada efeito sozinho, pelo nome:

| Nome | Quando toca |
|---|---|
| `CorteCavaleiro` | golpes 1 e 2 do combo (na altura do peito, virado para o golpe) |
| `CorteGiratorio` | golpe 3, o giro de 360° |
| `Tornado` | o tornado do ataque carregado (no chão, acompanha o tornado) |
| `CargaCavaleiro` | enquanto segura o ataque (no chão, embaixo do Cavaleiro) |
| `EscudoErguido` | enquanto defende (na frente do escudo, acompanha o braço) |
| `DefesaPerfeita` | defesa perfeita (no escudo, virado para quem atacou) |
| `Julgamento` | supremo do Cavaleiro (no chão, no ponto do impacto) |
| `ImpactoCorte` | a espada do Cavaleiro acerta um inimigo |
| `Rolamento` | começo do rolamento (dash) do Cavaleiro |
| `Redemoinho` | habilidade (E) do Cavaleiro, enquanto ele gira |

1. No Studio, monte o efeito com o plugin (uma **Part**, um **Model** ou um **Attachment** com ParticleEmitters, Beams e Trails dentro) e dê a ele um dos nomes da tabela.
2. Para testar na hora: crie a pasta **ReplicatedStorage > EfeitosVFX** e coloque o efeito dentro. Dê Play.
3. Para guardar no projeto: botão direito no efeito > **Save to File...** e salve como `.rbxmx` na pasta `vfx/` do projeto. O `py build.py` (ou o Rojo) coloca tudo em EfeitosVFX.

Atributos opcionais (em **Properties > Attributes**):
- No efeito: `Duracao` (segundos) e `Substituir` (marcado = esconde o efeito feito por código e mostra só o seu).
- Em cada ParticleEmitter: `EmitCount` (solta essa quantidade de uma vez) e `EmitDelay` (espera antes de soltar). Sem `EmitCount`, o emissor fica ligado enquanto o efeito durar.

Sem efeitos na pasta, o jogo usa os efeitos feitos por código normalmente.

## Conferir as animações sem abrir o Studio

`ferramentas/ver_poses.py` desenha o personagem (R15, com espada e escudo) em várias vistas e o caminho da ponta da espada, usando as poses reais de `Poses.luau`. Precisa de `pip install numpy pillow` e do `luau.exe` (github.com/luau-lang/luau/releases):

```
py ferramentas/ver_poses.py --luau CAMINHO/luau.exe --acao ataque3 --tempos 0.09,0.2,0.3,0.42 --saida giro.png
```

## Publicar no Roblox

1. **File > Publish to Roblox**.
2. Para o progresso salvar também no Studio: **Game Settings > Security > Enable Studio Access to API Services**.
3. O arquivo do jogo já vem com **R15** e com as juntas clássicas (StarterPlayer > AvatarJointUpgrade = Disabled). Se mudar em **Game Settings > Avatar**, mantenha **R15**: os golpes usam cotovelo, pulso e cintura, que o R6 não tem.

**As animações não aparecem?** Dê Play e abra a janela **Output** (View > Output). Deve aparecer a linha `[Animacoes] Personagem R15 com 15 juntas (...): animações ligadas.` Se aparecer outro aviso `[Animacoes]` (sem juntas, R6 ou um erro), copie essa linha: ela diz exatamente o que está errado.

## Onde mudar cada coisa

| Arquivo | Para quê |
|---|---|
| `src/shared/Config.luau` | Balanceamento geral, temas e inimigos de cada andar |
| `src/shared/Classes.luau` | Números das quatro classes |
| `src/shared/Cartas.luau` | Cartas e seus efeitos |
| `src/server/Inimigos.luau` | Vida, dano e ataques de inimigos e chefes |
| `src/server/Combate.luau` | Combos, habilidades, supremos, esquiva, escudo, mana, sangramento, dano |
| `src/shared/Teclas.luau` | Ações e teclas padrão (menu ⚙️ Teclas) |
| `src/client/Sons.luau` | Volume e variação de cada efeito sonoro |
| `ferramentas/gerar_sons.py` | Como cada som é criado (síntese) |
| `src/client/Poses.luau` | Poses e golpes de cada classe (quadros-chave das animações) |
| `src/client/Vfx.luau` | Efeitos visuais (cortes, tornado, círculo mágico, barreira do escudo...) |
| `vfx/` | Efeitos prontos do plugin (`.rbxmx`), veja "Efeitos do plugin" |
| `modelos/EspadaCavaleiro.rbxmx` | Espada do Cavaleiro (vai para ServerStorage > ModelosArmas; o cabo fica no -Z) |
| `pacotes/` | Pacotes baixados guardados sem scripts (insira no Studio com Insert from File) |
| `src/server/Masmorra.luau` | Construção e decoração das salas |
| `src/server/Lobby.luau` | Acampamento, altares, portal, mercador |
| `src/client/Modelos.luau` | **Aparência dos inimigos** (peças, cores, armas) |
| `src/client/VisualInimigos.luau` | Animações dos inimigos |
| `src/client/Vfx.luau` | Efeitos visuais |
| `src/client/Hud.luau` e `Menus.luau` | Interface |
| `src/client/UI.luau` | Cores, fontes e estilo dos painéis e botões |

Depois de editar os arquivos em `src/`, rode `py build.py` para gerar o `.rbxlx` de novo e reabra no Studio. Se preferir, use o [Rojo](https://rojo.space/) (`rojo serve`) para sincronizar ao vivo.
