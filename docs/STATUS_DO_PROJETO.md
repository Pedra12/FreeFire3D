# Status do projeto FreeFire3D

Atualizado em 2026-11-02.

## Mapa principal: Bermuda Masterizado

- O cenário principal foi alterado para usar o arquivo completo `bermuda-remastered-free-fire.zip`.
- O GLB `free_fire_full_bermuda_remastered.glb` é extraído diretamente do pacote original durante a compilação.
- O modelo contém 7 malhas, 28.955 vértices, 23.389 triângulos e 5 materiais.
- As 5 referências de textura estão incorporadas e carregadas; nenhuma textura ausente foi identificada na auditoria.
- Dimensões aproximadas: 142,49 × 142,49 unidades, com relevo vertical de 8,64 unidades.
- A cena principal preserva terreno, construções, ruas, relevo e água do modelo original.
- O mapa branco anterior não é apagado do repositório; permanece disponível como arquivo de origem/backup.

## Colisões

- Foi adicionado um construtor de colisões estáticas trianguladas diretamente a partir das malhas importadas.
- A colisão acompanha a geometria real do terreno e das construções; não substitui o terreno por uma superfície plana.
- A geração é executada quando a cena inicia e é verificada no smoke test do Godot.
- A geometria de água também pode receber colisão nesta primeira versão; deve ser revisada quando o controlador do jogador e as regras de navegação forem integrados.

## Compilação Android

- Godot: 4.7.2 stable.
- Plataforma: Android arm64-v8a, orientação paisagem.
- O workflow extrai o GLB do ZIP original e o inclui no APK.
- A compilação deve validar importação, carregamento da cena, geração de colisões, exportação e integridade do APK.

## Ainda não implementado

- Personagem Olivia e animações.
- Controlador de terceira pessoa.
- Analógico, câmera de mira, tiro e pulo.
- Bots, armas funcionais, HUD de combate e partidas.
- Otimização de desempenho em aparelho Android real.
