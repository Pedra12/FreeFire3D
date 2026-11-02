# Plano de reconstrução do mundo 3D

## Objetivo
Substituir a cena de teste baseada no mapa Bermuda simplificado por uma base de mundo 3D construída a partir dos recursos completos já presentes no repositório. O projeto deve avançar por integração real na cena principal, não por protótipos isolados.

## Ativo de mundo prioritário
River Side (arquivo River_Side_3D_Model_Free_Fire.usdz): auditoria anterior identificou 450 malhas, aproximadamente 295.648 vértices, 570.383 faces e 65 texturas. É um cenário muito mais rico que o GLB Bermuda Remasterizado atualmente usado na cena principal (7 malhas e aproximadamente 23.389 triângulos).

O primeiro bloqueio técnico é converter o USDZ para GLB mantendo materiais e texturas. O workflow .github/workflows/river-side-world-rebuild.yml faz essa conversão em Blender e publica um artefato de auditoria. A conversão precisa ser validada antes de substituir a cena principal.

## Ordem de integração
1. Converter USDZ para GLB e confirmar que texturas, materiais, dimensões e geometria foram preservados.
2. Normalizar escala e orientação com base em dimensões medidas, sem achatar relevo.
3. Dividir o mundo em setores e criar LODs / colisões simplificadas para Android.
4. Gerar uma cena de mundo única e trocar a referência do mapa na cena principal.
5. Reposicionar pontos de spawn e testar navegação, colisão, câmera e desempenho no mapa novo.
6. Integrar personagem rigado e animações, arma anexada à mão, HUD, combate e bots na mesma cena principal.
7. Só então exportar APK e comparar visualmente a versão instalada com a anterior.

## Outros recursos catalogados
- Nexterra FBX: 138 malhas, cerca de 96 mil vértices, 40 texturas.
- Circuit OBJ: cerca de 233 mil vértices e 140 mil faces.
- Clocktower: pacote Blender/FBX/OBJ com estruturas de edifícios.
- NeoParadise: pacote Blender com terreno, água, estrada e edifícios.
- AWM, SPAS12 e outros modelos de armas.
- Personagem Quaternius rigado com biblioteca de animações (86 clipes no build atual).

Esses pacotes não devem ser simplesmente empilhados no mesmo cenário. Primeiro é preciso identificar quais pertencem ao mesmo mapa, medir escala/orientação e separar assets de cenário, props e personagens.

## Limites e segurança
Os arquivos do APK Android analisado são majoritariamente ponte Unity/Android e SDKs. Não contêm o código-fonte completo da lógica do Free Fire. A reconstrução implementa sistemas equivalentes próprios; não remove proteções, não replica serviços proprietários e não reutiliza código proprietário na distribuição.

## Critério de aceite
Nenhuma mudança será chamada de concluída apenas porque compilou. O mapa convertido precisa ser inspecionado; a cena principal precisa referenciá-lo; testes automatizados devem confirmar spawn, colisão, personagem, arma, HUD e bots; o APK precisa conter o novo recurso e ter tamanho/hash registrados.
