# Status do projeto FreeFire3D

Atualizado em 2026-11-02.

## Primeiro teste Android

**Build concluído**

- Workflow: [First Android map test build](https://github.com/Pedra12/FreeFire3D/actions/runs/41368275211)
- Godot: 4.7.2 stable.
- Plataforma: Android, arm64-v8a, orientação paisagem.
- APK de depuração: 38.8 MB.
- Integridade ZIP/APK: verificada.
- Manifesto Android: pacote `com.pedra12.freefire3d.test`, SDK alvo 36.
- Biblioteca nativa arm64: presente.
- Importação GLB pelo Godot: concluída.
- Smoke test headless do projeto: concluído sem erro de cena/script.
- SHA-256 do APK: `24bceb3fd0f29bba741bd97cfe3e3d04d36d5ace530f18a5200aebf5974cdbbc`.

## Mapa integrado no teste

- Base: `hh.blend` dentro de `free-fire-ful-map.zip`.
- Bloco candidato: modelo Clocktower.
- 9 malhas da base + 38 malhas Clocktower = 47 malhas exportadas.
- Conversão de coordenadas do Clocktower: Y-up para Z-up, seguida de exportação GLB para Godot.
- Deslocamento vertical de teste do bloco: -20 unidades.
- 38 nós de textura reconectados por nome de arquivo.
- Uma referência de textura permanece sem correspondência: `tex_0000_0out.png`.
- As duas texturas NeoParadise do mapa principal continuam ausentes; por isso a base permanece branca no teste.
- Os ZIPs originais do repositório não foram alterados.

## Escopo desta primeira compilação

Esta é uma compilação técnica para validar importação, escala inicial, orientação paisagem e exportação Android. Inclui o cenário e rotação de câmera por toque. Ainda não inclui Olivia, armas, bots, HUD de combate, colisões finais ou partidas.

## Próximas etapas

1. Testar o APK em aparelho Android e conferir enquadramento, escala, texturas e desempenho.
2. Corrigir materiais ausentes e validar se o bloco Clocktower deve permanecer nessa posição.
3. Integrar Olivia, esqueleto/animações e colisões.
4. Adicionar movimento de terceira pessoa, mira e disparo.
5. Implementar bots e HUD mobile.
