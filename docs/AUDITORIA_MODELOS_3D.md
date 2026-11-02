# Auditoria aprofundada dos modelos 3D

Branch: \`reverse-engineering-audit\`  
Execução-base: \`41384874071\`  
Escopo: importação isolada dos formatos suportados pelo Blender. Nenhum asset da cena principal foi alterado.

## Resultados medidos

| Recurso | Geometria | Dimensões importadas | Rig/animação | Decisão |
|---|---:|---:|---|---|
| Bermuda Masterizada GLB | 28.955 vértices / 23.389 polígonos | 142,49 × 142,49 × 8,64 | Sem rig | Manter como mapa-base atual |
| Clocktower BLEND/OBJ | 46.176 vértices / 26.307 polígonos / 38 malhas | 87,25 × 113,65 × 27,57 | Sem rig | Bom candidato a conjunto de construções; revisar eixo, origem e materiais |
| The Circuit OBJ | 232.981 vértices / 139.819 polígonos / 56 malhas | 428,20 × 433,82 × 76,37 | Sem rig | Cenário grande; precisa LOD, colisão simplificada e revisão de texturas |
| NeoParadise BLEND | 28.724 vértices / 23.506 polígonos / 9 malhas | 2.032 × 2.032 × 122,44 nos transforms importados | Sem rig | Não substituir Bermuda; escala/transforms precisam ser normalizados antes de comparar |
| Lone Wolf GLTF | 136.173 vértices / 81.494 polígonos / 21 malhas | 1.600,83 × 51,93 × 14,15 | Sem esqueleto; ações detectadas pertencem a câmera/objeto | Tratar como cenário/estrutura, não personagem |
| Bunny Bundle OBJ | 4.755 vértices / 6.926 polígonos / 5 malhas | 0,644 × 0,220 × 1,037 | Sem rig | Não serve como personagem animado sem rigging |
| Rayan OBJ | 5.980 vértices / 7.943 polígonos / 6 malhas | 2,082 × 1,130 × 4,853 | Sem rig | Não usar diretamente; escala/eixo e rigging pendentes |
| Olivia GLB | 12.079 vértices / 17.719 polígonos / 7 malhas | 2,792 × 0,883 × 5,078 | Sem rig | Modelo estático; não é substituto direto do personagem jogável |
| Criminal Bundle OBJ | 5.122 vértices / 7.914 polígonos / 4 malhas | 2,290 × 0,914 × 4,647 | Sem rig | Estático; precisa rigging para gameplay |
| Gun BLEND | 6.141 vértices / 5.975 polígonos / 3 malhas | 0,611 × 0,276 × 0,203 | Sem rig | Candidato a arma estática; validar orientação e encaixe na mão |
| SPAS12 OBJ | 2.908 vértices / 2.581 polígonos | 1,978 × 0,155 × 0,570 | Sem rig | Candidato a arma estática; normalizar eixo e escala |
| AWM GLB | 3.634 vértices / 3.321 polígonos | 0,00554 × 0,000385 × 0,00109 | Sem rig | Importação em escala minúscula; requer correção de escala antes de uso |

## Limitações identificadas na primeira importação

- O importador FBX embutido na versão do Blender usada pelo runner falhou com erro interno \`ImportFBX.files\`. Isso não prova que os FBX estejam corrompidos. A próxima execução tenta conversão por Assimp antes da leitura.
- O importador USD não estava disponível no Blender do runner. A próxima execução adiciona inspeção com OpenUSD via Python, em vez de depender do operador USD do Blender.
- Ações chamadas \`CameraAction\` e \`CubeAction\` não são prova de animação de personagem. Só considerar animação jogável quando houver esqueleto, canais de animação associados aos ossos e movimentos relevantes.
- Dimensões importadas dependem de eixo, unidade, transform e escala de objeto. Não comparar números entre arquivos antes de normalizar os transforms.

## Decisões para o projeto

1. Preservar Bermuda Masterizada como mapa principal, como solicitado.
2. Não trocar o personagem atual por Olivia, Rayan ou Bunny Bundle: nenhum desses arquivos tem armature/bones no resultado medido.
3. Manter o humanoide rigado CC0 já integrado como base provisória para animação; validar a arma na mão antes de substituir qualquer modelo.
4. Avaliar o Clocktower como conjunto de prédios/props em uma cena de teste separada. Não despejar as 38 malhas no mapa principal antes de conferir materiais, colisões e escala.
5. Não importar The Circuit ou Lone Wolf como mapas inteiros no Android sem LOD, divisão por setores e colisões simplificadas.
6. Auditar AWM e SPAS12 por escala/orientação; a geometria isolada não comprova que estejam prontos para uso.

## Próxima etapa técnica

A execução expandida converte FBX com Assimp e inspeciona USD com OpenUSD. Depois disso, a próxima entrega deve ser um pacote de teste isolado contendo:
- Clocktower com materiais e texturas corrigidos;
- arma escolhida alinhada a uma mão de referência;
- uma cena de teste com o personagem rigado atual;
- medições de escala com uma altura de referência consistente.

A cena principal e o controlador de movimento permanecem intocados até que a cena de teste seja validada.
