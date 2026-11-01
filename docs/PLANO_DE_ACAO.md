# Plano de ação — FreeFire3D

## Objetivo
Criar um jogo mobile 3D de batalha em terceira pessoa, para Android, com partidas offline contra bots e apresentação inspirada em jogos como Free Fire. O projeto será desenvolvido do zero, sem copiar a estrutura defeituosa do protótipo anterior.

## Regras do projeto
- O repositório antigo `Pedra12/FreeFire2D` permanece intacto e serve apenas como referência e fonte de assets.
- Não integrar sistemas novos enquanto a etapa atual não passar nos testes.
- Não usar cubos, cápsulas ou terrenos provisórios como substitutos silenciosos dos assets finais.
- Não dimensionar personagens ou cenário por tentativa visual: definir escala de referência e validar medidas.
- Texturas devem estar incorporadas ou em caminhos relativos válidos; nada de depender de arquivos externos ausentes.
- Cada etapa deve gerar evidência verificável: log de importação, execução, captura de tela ou APK de teste.
- Prioridade inicial: Android em modo paisagem, controles por toque e desempenho estável em aparelho intermediário.

## Fases

### 0. Preparação e inventário
- Confirmar versão estável do Godot 4.x e configuração de exportação Android.
- Auditar todos os ZIPs e modelos disponíveis no repositório antigo.
- Identificar formato, tamanho, licença, dependências, materiais, texturas, esqueleto e animações de cada asset.
- Separar assets aprovados, assets que precisam de conversão e assets incompatíveis.
- Registrar a origem/licença dos recursos antes de incluí-los.

**Critério de conclusão:** inventário dos assets e estrutura de pastas definidos; projeto vazio importa sem erros.

### 1. Base técnica e escala
- Criar projeto Godot 3D limpo, renderização compatível com Android.
- Definir convenção de unidades: 1 unidade Godot = 1 metro.
- Criar cena de teste com escala humana, portas, paredes, escadas e objetos de referência.
- Configurar iluminação, ambiente, sombras e qualidade gráfica inicial.
- Configurar orientação paisagem e resolução adaptável.

**Critério de conclusão:** cena de teste abre e roda no Android sem erros, com escala coerente.

### 2. Mapa e ambiente
- Avaliar o mapa completo original antes de integrá-lo.
- Corrigir escala, orientação, origem, geometria e materiais no Blender quando necessário.
- Recuperar/substituir corretamente texturas ausentes, sem texturas genéricas aplicadas ao acaso.
- Organizar terreno, casas, estradas, vegetação, água e objetos por grupos.
- Criar colisões adequadas e remover objetos flutuantes, enterrados ou duplicados.
- Testar pontos de spawn e alturas em várias regiões do mapa.

**Critério de conclusão:** mapa visualmente aprovado em capturas de vários ângulos; colisões e alturas verificadas; nenhum jogador ou objeto atravessa o terreno nos pontos testados.

### 3. Personagem e animações
- Escolher um personagem humanoide com proporções corretas e rig compatível.
- Conferir escala real, orientação dos eixos, esqueleto e animações disponíveis.
- Configurar idle, caminhada, corrida, salto, queda, mira, disparo e recarga.
- Corrigir encaixe da arma nas mãos e transições entre animações.

**Critério de conclusão:** personagem mantém proporções corretas no mapa e executa as animações sem travamentos, deformações ou deslocamento invertido.

### 4. Movimento e câmera
- Implementar controle de terceira pessoa.
- Analógico virtual esquerdo para movimento.
- Arrasto no lado direito para girar a câmera, sem travar o deslocamento.
- Movimento relativo à direção da câmera, com o personagem virando para a direção real do movimento.
- Implementar corrida, salto, gravidade e colisão com obstáculos.
- Ajustar sensibilidade, suavidade e limites da câmera.

**Critério de conclusão:** movimentação e câmera funcionam simultaneamente, sem andar para trás, congelar ou atravessar objetos.

### 5. Combate e armas
- Implementar mira, disparo, recarga, munição e troca de armas.
- Integrar primeiro uma arma de referência; depois adicionar as demais.
- Criar dano, alcance, recuo, dispersão e feedback de acerto.
- Adicionar efeitos visuais e sonoros leves, otimizados para Android.

**Critério de conclusão:** ciclo de combate completo funciona em teste controlado.

### 6. Bots e partida
- Criar bots com percepção, movimentação, busca de cobertura e combate.
- Implementar vida, eliminação, coleta de itens e zona segura.
- Criar partida offline com início, meio e fim, incluindo tela de vitória/derrota.
- Ajustar dificuldade e quantidade de bots de acordo com o desempenho do aparelho.

**Critério de conclusão:** partida offline pode ser iniciada, jogada e concluída sem intervenção externa.

### 7. HUD e experiência mobile
- HUD em paisagem inspirado na organização de controles de jogos mobile do gênero.
- Botões de tiro, mira, pulo, corrida, recarga e interação.
- Indicadores de vida, munição, minimapa e zona.
- Ajustar áreas de toque, escala e posicionamento para diferentes telas.

**Critério de conclusão:** todos os controles são utilizáveis no telefone e não cobrem informações essenciais.

### 8. Otimização, testes e entrega
- Testar importação limpa, execução prolongada e exportação Android.
- Medir FPS, memória, tamanho do APK e tempos de carregamento.
- Reduzir polígonos, texturas e efeitos quando necessário, preservando a qualidade visual.
- Corrigir erros encontrados e repetir os testes de regressão.
- Gerar APK de teste e registrar versão/alterações.

**Critério de conclusão:** APK instala e inicia no Android; controles, mapa e partida passam pela lista de testes.

## Ordem de prioridade
1. Inventário e projeto limpo.
2. Escala e teste visual.
3. Mapa aprovado.
4. Personagem e animações.
5. Movimento e câmera.
6. Combate.
7. Bots e partida.
8. HUD final.
9. Otimização e APK.

## Fora do primeiro marco
- Multiplayer online e matchmaking.
- Loja, passe, progressão online e contas.
- Sistemas sociais e servidores dedicados.

Esses recursos ficam para depois que a partida offline estiver estável. Primeiro precisamos de um jogo que funcione; depois podemos dar a ele problemas de rede.
