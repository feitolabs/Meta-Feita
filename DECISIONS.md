# Registro de Decisões Técnicas — Meta Feita

Este arquivo documenta as decisões de arquitetura, bibliotecas e definições de desenvolvimento em conformidade com `CONTEXTOS/regras app.md` e os documentos de especificação `Rendix_01` e `Rendix_02`.

## 1. Resolução de Stack (regras app.md sobre Rendix_01)

| Camada | Especificação inicial (Rendix_01) | Decisão final (`regras app.md`) | Justificativa |
|---|---|---|---|
| Frontend | Next.js + React + Capacitor | **Flutter (Dart)** | Atende Android, iOS e Web responsivo com uma única base de código e alto controle visual do protótipo. |
| Backend de monetização | Backend mínimo HTTP | **Python (FastAPI + Pydantic + SQLite)** | Requisito explícito de backend em Python, isolado para catálogo, compras, webhooks e ledger de créditos. |
| Persistência local | IndexedDB + Dexie + LocalStorage | **`localstorage` (`localstorage: ^6.0.0`)** | Requisito explícito de banco local via `localstorage` com esquema JSON versionado em dispositivo. |
| Repositório | GitHub | `https://github.com/feitolabs/Meta-Feita` | Repositório oficial do projeto. |

## 2. Bibliotecas Escolhidas

### Flutter (`app/pubspec.yaml`)
- `decimal: ^3.2.6`: aritmética decimal exata sem erros binários de ponto flutuante (Doc 02 §2.3).
- `localstorage: ^6.0.0`: persistência local multiplataforma em dispositivo para simulações, metas, preferências e cache de créditos.
- `flutter_svg: ^2.3.2`: renderização exata dos 32 ícones de interface e 5 variantes do símbolo da marca.
- `fl_chart: ^1.3.0`: gráficos acessíveis com eixos, legendas e tooltips para evolução de saldo, comparação e inflação.
- `http: ^1.6.0`: comunicação HTTPS com o backend mínimo de monetização.
- `intl: ^0.20.3`: formatação monetária BRL (`pt_BR`) e datas civis.
- `uuid: ^4.6.0`: geração de `idempotencyKey` e referências anônimas de carteira.
- `file_picker: ^13.3.2`, `share_plus: ^13.3.1`, `path_provider: ^2.1.6`: exportação e restauração de backup JSON versionado.

### Python (`backend/requirements.txt`)
- `fastapi`, `uvicorn`, `pydantic`, `pydantic-settings`: API REST tipada e configuração exclusivamente por variáveis de ambiente (`.env`), sem segredos hardcoded.
- `pytest`, `httpx`: testes automatizados de unidade, integração, idempotência e segurança.

## 3. Definições Matemáticas e de Produto (Doc 01 §16 e Doc 02 §19)

1. **Convenção de datas**: Simulações padrão mensais usam períodos discretos ordenados (`1..n`). Frequências distintas ou aportes irregulares utilizam linha do tempo cronológica com datas civis (`DateTime(ano, mes, dia)` sem deslocamento por fuso horário), sem converter silenciosamente mês em 30 dias.
2. **Faixa de taxas**: Taxas negativas são permitidas desde que a taxa efetiva equivalente do período seja estritamente maior que `-100%` (`> -1.0`). Taxas `<= -100%` são rejeitadas.
3. **Precisão e arredondamento**: Cálculos intermediários usam aritmética `Decimal` de alta precisão (20+ casas em raízes Newton-Raphson). Arredondamento comercial (`half-up`) para 2 casas decimais é aplicado na apresentação monetária e na liquidação de caixa em eventos discretos (como compra inteira/fracionária de cotas).
4. **Cotas fracionárias**: Precisão máxima configurável de até 6 casas decimais (`scale = 6`), exibindo aviso explícito de que o modo fracionário é uma hipótese de simulação.
5. **Custos e impostos**: Zero por padrão; aplicados apenas quando informados explicitamente pelo usuário (ex.: simulador de reinvestimento).
6. **Catálogo de créditos e preços**: Configurado em `backend/catalog.json` (versionado e substituível por ambiente), nunca hardcoded de forma arbitrária na interface.
7. **Recuperação de carteira anônima**: Ao criar uma carteira pseudônima (`walletReference`), o cliente gera localmente ou solicita código de recuperação exibido uma única vez; o backend armazena apenas o hash PBKDF2-HMAC-SHA256 desse código, sem dados financeiros nem senhas em código-fonte.
8. **Anúncios e pagamentos**: IDs de teste oficiais no ambiente de desenvolvimento; adaptadores desacoplados para Google Play Billing e provedor de checkout Web com validação HMAC via webhook.
9. **Recompensa de anúncio em produção**: o crédito só é concedido pelo callback SSV do AdMob, assinado pelo Google e restrito aos blocos autorizados. O aplicativo apenas aguarda o registro no extrato. O endpoint `/v1/ads/rewarded/claim` atende somente a blocos de teste em desenvolvimento.
10. **Compras no Android**: consumíveis Google Play validados no servidor antes do consumo, com `autoConsume` desligado. Se a validação falhar, a compra continua pendente e é retomada ao reabrir o app. O checkout Web fica restrito à plataforma Web.
11. **Banco de dados**: SQLite por padrão e PostgreSQL quando `META_FEITA_DATABASE_URL` está definida, com trava por carteira durante cada transação.

