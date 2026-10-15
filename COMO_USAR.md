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
| `src/client/Poses.luau` | Poses e golpes de cada classe (quadros-chave das animações) |
| `src/server/Masmorra.luau` | Construção e decoração das salas |
| `src/server/Lobby.luau` | Acampamento, altares, portal, mercador |
| `src/client/Modelos.luau` | **Aparência dos inimigos** (peças, cores, armas) |
| `src/client/VisualInimigos.luau` | Animações dos inimigos |
| `src/client/Vfx.luau` | Efeitos visuais |
| `src/client/Hud.luau` e `Menus.luau` | Interface |
| `src/client/UI.luau` | Cores, fontes e estilo dos painéis e botões |

Depois de editar os arquivos em `src/`, rode `py build.py` para gerar o `.rbxlx` de novo e reabra no Studio. Se preferir, use o [Rojo](https://rojo.space/) (`rojo serve`) para sincronizar ao vivo.

## Sons

O jogo usa só sons que já vêm com o Roblox. Para deixar mais imersivo, pegue sons na Creator Store do Roblox (golpes, explosões, música ambiente) e coloque os IDs em `UI.SONS` (`src/client/UI.luau`).
