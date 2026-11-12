# Ficha da Play Store — Meta Feita

**Nome do app** (até 30 caracteres)

```
Meta Feita: Planejar Finanças
```

**Descrição curta** (até 80 caracteres)

```
Simule juros compostos, dividendos, metas e aposentadoria com contas claras.
```

**Descrição completa** (até 4.000 caracteres)

```
Meta Feita ajuda você a planejar o seu dinheiro com números que você entende. Informe valores e prazos, veja o resultado na hora e entenda cada premissa do cálculo.

CALCULADORAS

• Juros compostos: capital inicial, aportes, taxa e prazo, com gráfico da evolução.
• Dividendos: quanto seus proventos podem render e o preço-teto de um ativo.
• Reinvestimento: simule a compra de novas cotas com os proventos.
• Comparador: coloque cenários lado a lado e veja a diferença.
• Inflação: compare o valor nominal com o poder de compra real.
• Retiradas: descubra por quanto tempo um patrimônio sustenta seus saques.
• Aposentadoria: acumulação e renda na fase de usufruto.
• Metas: calcule quanto falta e qual aporte leva você até o objetivo.

SEUS DADOS FICAM COM VOCÊ

Sem cadastro e sem login. Simulações, metas e histórico ficam gravados no seu aparelho e funcionam mesmo sem internet. Você pode exportar um backup ou apagar tudo quando quiser. Seus valores nunca são enviados aos anúncios.

CONTAS CLARAS

Os cálculos usam precisão decimal, com arredondamento explícito em reais. As fórmulas e premissas estão disponíveis dentro do app.

GRÁTIS, COM CRÉDITOS OPCIONAIS

Todas as calculadoras essenciais são gratuitas. O app exibe anúncios. Recursos avançados usam créditos, obtidos em compra única ou assistindo a um anúncio premiado. Não há assinatura, e o custo aparece antes de cada uso.

AVISO

O Meta Feita é uma ferramenta de simulação matemática. Os resultados são estimativas baseadas nas premissas que você informa e não constituem recomendação de investimento, consultoria financeira ou garantia de rentabilidade.
```

## Arquivos gráficos

| Item | Exigência | Situação |
|---|---|---|
| Ícone | 512 x 512 PNG | Pronto: `CONTEXTOS/2-android/google-play/ic_play_store_512.png` |
| Imagem de destaque | 1024 x 500 PNG ou JPG | Pronta: `docs/play-store/imagens/imagem-de-destaque.png` |
| Capturas de celular | de 2 a 8 imagens, proporção até 16:9 ou 9:16 | Prontas: 8 imagens 1080 x 1920 em `docs/play-store/imagens/` |

Para gerar as imagens de novo depois de mudar o visual, rode na pasta `app/`:

```bash
flutter test --update-goldens tool/store_assets_test.dart
```

## Categoria

- Categoria: **Finanças**
- Contém anúncios: **Sim**
- Compras no app: **Sim** (de R$ 4,90 a R$ 24,90 por item)
