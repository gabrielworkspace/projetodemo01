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

**Escudo (Cavaleiro):** segurando a defesa, golpes vindos da frente perdem 75% do dano. Erguendo o escudo logo antes do golpe (até 0,3s), é uma **defesa perfeita**: não leva dano nenhum e atordoa quem atacou. Com o escudo erguido o Cavaleiro anda devagar e não ataca.

**Mana (Mago):** toda magia gasta mana, que volta sozinha com o tempo e enche ao entrar numa sala nova. O combo é Dardo Arcano → Lança de Gelo (deixa lento) → Bola de Fogo (explode e queima), e o golpe carregado é o Orbe do Vazio, que puxa os inimigos enquanto voa. Cartas como Fonte Arcana, Reservatório Arcano, Sifão de Almas e Mente Serena ajudam na mana.

**Sangramento (Assassino):** cada golpe abre um corte e o inimigo sangra por 4 segundos, acumulando até 5 vezes.

**Golpe carregado** (segure o ataque e solte): Cavaleiro gira a espada, Mago lança o Orbe do Vazio, Arqueiro dispara uma flecha perfurante e Assassino avança cortando tudo numa linha (Investida Letal).

**Pelas costas:** o Assassino causa +50% de dano acertando o inimigo por trás. Funciona muito bem junto com o Cavaleiro, que atrai a atenção.

Cada classe também tem uma **pose própria** parada: o Cavaleiro em guarda, o Mago ereto conjurando luz, o Arqueiro relaxado olhando em volta e o Assassino agachado e inclinado.

Cada classe tem pelo menos **11 cartas próprias** (o Mago tem 15, com as de mana), e existem **11 cartas universais**.

## Mecânicas

- **Combo:** todo terceiro ataque é um golpe final mais forte.
- **Esquiva:** você fica invulnerável por um instante e atravessa projéteis.
- **Avisos no chão:** áreas vermelhas mostram onde o golpe do inimigo vai cair. O círculo de dentro enche até a hora do golpe.
- **Caído e reviver:** quem perde toda a vida cai. Um aliado precisa ficar perto por 3 segundos para levantar quem caiu. Sem ajuda em 15 segundos, a pessoa só volta quando a sala for limpa.
- **Ameaça:** os inimigos atacam quem causa mais dano. O Cavaleiro chama o dobro de atenção, então ele funciona como o tanque do grupo.
- **Elites:** inimigos com ★ e um poder (Blindado, Veloz, Gélido, Explosivo, Gigante). Dão 3x mais ouro.
- **Temas e chefes:** Calabouço (Rei Esqueleto), Caverna (Rainha Aranha), Cripta (Lich Gélido) e Fornalha (Senhor das Chamas). Os chefes têm uma segunda fase com metade da vida.

## Efeitos visuais

Os efeitos usam partículas com texturas: as que já vêm com o Roblox (fogo, fumaça, explosão, onda de choque, implosão, vórtice) e **texturas desenhadas pelo próprio jogo** quando ele abre (lua de corte, estrela de crítico, onda de choque, círculo mágico com runas, raio, chama, fumaça, faísca em rastro). Para as texturas próprias funcionarem no jogo publicado, ligue **Game Settings > Security > Allow Mesh / Image APIs**. Sem isso, o jogo usa só as texturas do Roblox (nada quebra; aparece um aviso no Output).

**Usar efeitos feitos no VFX Studio (ou da Creator Store):** crie a pasta `EfeitosCustom` dentro de **ReplicatedStorage** e coloque o efeito lá com um destes nomes: `Impacto`, `Critico`, `Corte`, `Explosao`, `Vazio`, `Esquiva`, `Defesa`, `CargaCheia`, `Morte`, `Sangue`, `Redemoinho`, `Julgamento`, `Meteoro`, `Raio`, `PassoSombrio`, `Supremo`. O efeito pode ser um Attachment, uma Part, um Model ou uma pasta com ParticleEmitters. Quando aquele momento acontece no jogo, o efeito é colocado no lugar e cada ParticleEmitter solta a quantidade do atributo **EmitCount** (padrão 20; o atributo **EmitDelay** atrasa); Beams e Trails ficam ligados pelo atributo **Duracao** (padrão 0,5s). Sem efeito com aquele nome, o jogo usa o efeito padrão.

**Animações dos personagens:** são feitas por código (não precisam de arquivos de animação). O arquivo do jogo já vem com **StarterPlayer > AvatarJointUpgrade = Disabled**; se você mudar isso, as animações continuam funcionando (o código aceita os dois tipos de junta). Se alguma vez o boneco não se mexer, veja a janela Output: o jogo avisa quando não encontra as juntas do personagem.

## Efeitos sonoros

O jogo tem 38 efeitos sonoros (cortes, flechas, magias, escudo, impactos, explosões, moedas, interface...). Eles foram **criados do zero por síntese** pelo script `ferramentas/gerar_sons.py` e ficam todos juntos em um arquivo só: `sons/MasmorraSons.ogg`. O Roblox não deixa colocar áudio dentro do arquivo `.rbxlx`, então é preciso enviar esse arquivo **uma vez**:

1. No Roblox Studio, abra **Window > Asset Manager** (ou **View > Asset Manager**) e clique em **Bulk Import**. Também dá pelo site: **create.roblox.com > Creations > Audio > Upload Asset**.
2. Escolha `sons/MasmorraSons.ogg` e confirme. Espere a moderação aprovar (costuma levar poucos minutos).
3. Copie o ID do áudio (no Asset Manager: botão direito > **Copy Asset ID**).
4. Em `src/shared/Config.luau`, cole o ID: `Config.SONS_ID = "rbxassetid://SEU_ID_AQUI"`.
5. Rode `py build.py` de novo e abra o `MasmorraDasCartas.rbxlx` (ou faça a mesma troca direto no Studio, em **ReplicatedStorage > Shared > Config**).

Envie o áudio pela **mesma conta (ou grupo) dona do jogo**; áudio de outra conta não toca. Enquanto o ID não for colocado, só as explosões têm som (um som que já vem com o Roblox) e aparece um aviso na janela Output.

Se preferir enviar os sons um por um, eles também estão separados em `sons/individuais/`; coloque cada ID em `Config.SONS_IDS` (por exemplo `espada = "rbxassetid://..."`). Para mudar um som, edite `ferramentas/gerar_sons.py` e rode `py ferramentas/gerar_sons.py` (precisa de `pip install numpy scipy` e do ffmpeg); depois envie o arquivo novo.

## Publicar no Roblox

1. **File > Publish to Roblox**.
2. Para o progresso salvar também no Studio: **Game Settings > Security > Enable Studio Access to API Services**.
3. Em **Game Settings > Avatar**, deixe **R15** (as animações das armas funcionam melhor).

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
| `src/server/Masmorra.luau` | Construção e decoração das salas |
| `src/server/Lobby.luau` | Acampamento, altares, portal, mercador |
| `src/client/Modelos.luau` | **Aparência dos inimigos** (peças, cores, armas) |
| `src/client/VisualInimigos.luau` | Animações dos inimigos |
| `src/client/Vfx.luau` | Efeitos visuais (cada golpe, magia e habilidade) |
| `src/client/VfxKit.luau` | Receitas de partículas e efeitos próprios (EfeitosCustom) |
| `src/client/TexturasGeradas.luau` | Desenho das texturas de efeito |
| `src/client/Hud.luau` e `Menus.luau` | Interface |
| `src/client/UI.luau` | Cores, fontes e estilo dos painéis e botões |

Depois de editar os arquivos em `src/`, rode `py build.py` para gerar o `.rbxlx` de novo e reabra no Studio. Se preferir, use o [Rojo](https://rojo.space/) (`rojo serve`) para sincronizar ao vivo.
