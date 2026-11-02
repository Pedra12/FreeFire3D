# Engenharia reversa técnica: arquitetura observável do Free Fire

Data da análise: 2026-11-02  
Escopo: leitura estática dos arquivos do repositório FreeFire3D, sem alteração do projeto jogável.

## 1. O que foi possível confirmar

O pacote Android analisado é \`com.dts.freefireth\`, versão declarada \`1.132.1\`. A atividade principal é \`com.dts.freefireth.FFMainActivity\`, configurada para paisagem por sensor. A inicialização de jogo passa pela camada \`com.unity3d.player.UnityPlayerActivity\`, que instancia \`UnityPlayer\` e encaminha eventos Android para a camada Unity.

A ponte Android -> Unity usa \`UnityPlayer.UnitySendMessage(gameObject, method, payload)\`. A implementação \`FFMainActivity.FFSendToUnity\` valida atividade, encerramento e nomes de objeto/método antes de enviar a mensagem. Isso demonstra uma arquitetura dividida em:
- engine e gameplay no lado Unity;
- integração com Android no lado Java;
- SDKs externos para conta, voz, pagamentos, notificações e distribuição de conteúdo.

**Limite importante:** o ZIP Java não contém os scripts C# de gameplay, assemblies IL2CPP, bundles completos nem bibliotecas nativas do jogo. Portanto, não revela o código interno de movimentação, tiro, bots, matchmaking, dano ou regras de partida. Não devemos fingir que esses sistemas foram recuperados.

## 2. Camadas Android identificadas

| Camada | Evidência observada | Equivalente recomendado no Godot |
|---|---|---|
| Ciclo de vida | \`FFMainActivity\`, \`UnityPlayerActivity\` e callbacks de pausa/retomada/configuração | Autoload \`GameLifecycle\` e sinais de \`NOTIFICATION_APPLICATION_*\` |
| Ponte de mensagens | \`FFSendToUnity\`, \`UnityMessenger\`, nomes de GameObject/método e payload JSON | Sinais tipados entre Autoloads e cenas, sem imitar a ponte Java |
| Recursos sob demanda | \`PlayAssetDeliveryUnityWrapper\`: download, consulta de estado, caminho, cancelamento e remoção de packs | \`ContentPackManager\` com pacotes locais versionados e carregamento assíncrono |
| Rede do dispositivo | \`FFNetworkConnectionManager\`: monitoramento, solicitação/liberação de rede, resolução DNS e bind de socket | \`NetworkStatus\` para conectividade; \`HTTPRequest\`/\`WebSocketPeer\` apenas quando houver backend próprio |
| Voz | \`VodkaUnity\`: login no SDK, canal, microfone, alto-falante, membros e eventos | Voz fica fora do primeiro marco offline; abstração \`VoiceChatAdapter\` para integração futura |
| Conta e identidade | \`SdkUnity\`: login, sessão, convidado, vínculo de contas e Google Play Games | Não implementar contas no protótipo offline; salvar perfil local com \`ConfigFile\` |
| Android nativo | \`FFAPI\`: bateria, memória, armazenamento, CPU, tela, permissões, clipboard, intents e imagens | \`OS\`, \`DisplayServer\`, permissões Android e plugins apenas se uma necessidade real aparecer |
| Notificações | Firebase e receiver de notificações | Fora da partida offline; não necessário para o primeiro APK |

## 3. Fluxo de execução observado

1. Android cria \`FFMainActivity\`.
2. A atividade inicializa o wrapper Unity e seu \`UnityPlayer\`.
3. A camada Android informa eventos e dados ao Unity através de mensagens direcionadas a objetos e métodos.
4. Serviços externos retornam callbacks que também são encaminhados à camada Unity.
5. A distribuição de conteúdo pode disponibilizar pacotes adicionais em caminhos locais.
6. A atividade encaminha eventos de ciclo de vida, configuração, permissões e resultados de outras atividades.

O fluxo acima é arquitetura de integração, não o fluxo interno de uma partida.

## 4. Arquitetura equivalente proposta para FreeFire3D

O projeto Godot deve manter os sistemas desacoplados. A estrutura recomendada é:

- \`GameRoot\`: controla menu, carregamento de mapa, início e fim da partida.
- \`PlayerController\`: movimento já aprovado. **Não alterar nesta etapa.**
- \`CameraRig\`: câmera de terceira pessoa e sensibilidade.
- \`CombatController\`: mira, disparo, recarga, munição e troca de arma.
- \`WeaponBase\`: dados e comportamento por arma.
- \`DamageSystem\`: aplicação de dano, hit feedback e eliminação.
- \`BotDirector\`: quantidade de bots e distribuição inicial.
- \`BotAI\`: percepção, navegação, cobertura, mira e combate.
- \`LootSystem\`: itens coletáveis, inventário e munição.
- \`MatchRules\`: tempo, zona segura, contagem de jogadores e condição de vitória.
- \`MobileHUD\`: controles de toque e indicadores.
- \`ContentPackManager\`: mapas e recursos carregados sob demanda.
- \`GameLifecycle\`: pausa, retomada, foco, orientação e saída.
- \`SaveService\`: configurações e progresso local.

Os módulos devem conversar por sinais e interfaces pequenas. O HUD não deve controlar diretamente a lógica de dano; o botão de tiro emite intenção de disparo e o \`CombatController\` valida munição, cadência e estado da arma.

## 5. Estado real do protótipo Godot lido no branch main

Arquivos observados:
- \`game/scripts/player_controller.gd\`
- \`game/scripts/mobile_hud.gd\`
- \`game/scripts/camera_orbit.gd\`
- \`game/scripts/map_collision_builder.gd\`
- \`game/scenes/main.tscn\`
- \`game/scenes/player.tscn\`

O controlador usa \`CharacterBody3D\`, velocidade de caminhada/corrida, salto, movimento relativo à câmera, rotação do personagem e seleção de animações. O HUD já reconhece analógico, mira, disparo e pulo. Contudo, o botão de disparo apenas altera o estado visual \`firing\`; não há ainda um ciclo real de arma, projétil/raycast, dano ou munição.

A cena principal instancia o GLB de Bermuda Masterizado com escala 1.5 e gera colisões trianguladas para as malhas. Isso preserva a geometria importada, mas exige auditoria específica para separar água, terreno e objetos que não devem bloquear o jogador.

A cena de personagem aplica escala 0.75 ao modelo e usa cápsula de colisão com raio 0.255 e altura 1.35. A proporção final em relação às casas ainda precisa ser medida no relatório de importação e validada visualmente; a redução de escala, sozinha, não prova que a escala ficou correta.

**Inconsistência documental:** \`docs/STATUS_DO_PROJETO.md\` ainda descreve controlador e HUD como não implementados, embora esses scripts estejam presentes no branch main. O status precisa ser atualizado depois que a auditoria dos assets terminar.

## 6. Ordem segura de reconstrução

1. Fechar a auditoria de formatos, dimensões, materiais, esqueleto e animações dos arquivos 3D.
2. Selecionar um modelo de personagem rigado e uma arma compatível; confirmar encaixe da arma e animações.
3. Preservar o controlador atual e adicionar apenas uma camada de combate independente.
4. Fazer uma arma funcionar por completo: equipar, mirar, disparar, recarregar, munição, impacto e dano.
5. Criar um bot de teste com estados simples: parado, patrulha, detectar, perseguir, procurar cobertura, atacar e morrer.
6. Criar uma partida offline pequena, com começo e fim.
7. Otimizar mapa e quantidade de bots com medições no Android.

## 7. Limites de segurança e propriedade intelectual

A análise é limitada a formatos, metadados, estruturas de integração e comportamento observável. A implementação será uma recriação independente em Godot. Não serão copiados códigos proprietários, contornados mecanismos de proteção/anti-cheat, acessados servidores privados nem reproduzidos sistemas de autenticação ou matchmaking do jogo original.

## 8. Próximo resultado verificável

O workflow \`Deep 3D asset and rig audit\` importa os modelos em ambiente isolado e registra dimensões, malhas, polígonos, materiais, armatures, ossos e animações. Nenhum arquivo da cena principal é modificado por essa auditoria. O relatório definirá quais recursos podem entrar no pipeline Godot e quais precisam de conversão, otimização ou rigging.
