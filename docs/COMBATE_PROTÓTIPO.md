# Protótipo de combate independente

Branch: \`combat-prototype\`  
Base: branch \`main\` sem alterar o controlador de movimento.

## O que foi adicionado

- \`CombatController\`: disparo hitscan a partir do centro da câmera, cadência, dano, alcance, munição e recarga.
- \`damageable_target.gd\`: componente de alvo com vida, feedback visual ao receber dano e eliminação.
- \`training_target.tscn\`: alvo de treino reutilizável.
- \`combat_test.tscn\`: campo isolado com piso e alvo, sem modificar a cena Bermuda.
- HUD: botão de recarga, contador de munição e retículo ao mirar.
- A câmera aproxima o campo de visão enquanto a mira está ativa.
- \`combat_smoke_test.gd\`: teste automatizado que dispara contra o alvo e verifica redução de vida.

## Decisões de segurança

- \`player_controller.gd\` não foi alterado.
- O sistema de combate fica em um nó filho separado do jogador.
- O teste usa uma cena isolada e não adiciona bonecos de treino ao mapa Bermuda.
- A cena principal continua usando o mapa Bermuda Masterizado.
- Nenhuma arma visual foi anexada à mão ainda; isso depende da auditoria do esqueleto e da escolha de modelo com escala e orientação corretas.

## Critério para integrar

O workflow Android precisa:
1. importar o projeto sem erros de script;
2. executar a auditoria de escala existente;
3. executar \`combat_smoke_test.gd\` e imprimir \`COMBAT_TEST_OK\`;
4. iniciar a cena principal sem erro;
5. exportar e validar o APK.

Só depois desses critérios a implementação deve ser considerada validada. O teste automatizado não substitui a verificação visual no aparelho Android.
