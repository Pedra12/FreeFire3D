# Assets importados para Godot

Esta pasta contém os arquivos de runtime aproveitados da preparação feita no projeto Unity. Os arquivos Unity originais e sua branch continuam preservados.

## Personagem: Olivia
- Runtime: `characters/olivia_rigged.glb`
- Modelo com 7 malhas skinned, 1 skin, 22 ossos e 10 texturas incorporadas.
- Altura preparada: aproximadamente 1,78 m.
- O modelo original não tinha rig. O esqueleto e os pesos foram preparados e passaram por teste de deformação e reimportação GLB.
- Origem: “Olivia free fire”, Xman, Sketchfab, licença CC BY. Manter atribuição ao autor na tela de créditos e em qualquer distribuição.

## Mapa: Clocktower
- Runtime: `maps/clocktower.glb`
- 38 malhas, 38 materiais e 10 imagens de textura incorporadas.
- As referências de textura foram corrigidas antes da exportação GLB.
- Origem: “FREE FIRE CLOCKTOWER 3D MODEL BY RS RATUL”, RS RATUL, Sketchfab, licença CC BY. Manter atribuição ao autor na tela de créditos e em qualquer distribuição.
- A geometria foi preparada como ambiente estático. Interiores acessíveis, colisões, navegação de bots e desempenho ainda precisam de validação no Godot e no aparelho.

## Animações: Quaternius
- Fonte: `animations/Quaternius/UAL1_Standard.fbx`
- Biblioteca Universal Animation Library [Standard], licença CC0 1.0.
- 43 clips identificados no relatório de origem; contém idle, walk, jog, sprint, crouch, jump, pistol aim/shoot/reload, entre outros.
- O FBX é mantido como fonte de animações. O retarget para o esqueleto da Olivia no Godot ainda precisa ser configurado e testado; não assumir que as animações já estão conectadas.

## Estado de validação
Os arquivos foram copiados sem conversão a partir dos GLBs/FBX já preparados. Isso confirma a presença dos assets no repositório, não a validação de importação ou execução pelo editor Godot. Próxima etapa: abrir o projeto, conferir importação dos GLBs, escala, orientação, materiais, esqueleto e animações.
