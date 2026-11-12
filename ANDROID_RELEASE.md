# Guia de Publicação Android (Google Play) — Meta Feita

Siga na ordem. Cada etapa depende da anterior. Comandos rodam no PowerShell, a partir da pasta `app/`, salvo indicação.

---

## 1. Chave de assinatura

```powershell
powershell -ExecutionPolicy Bypass -File scripts\create_keystore.ps1
```

O script cria `android/meta-feita-release.jks` e `android/key.properties`. Os dois ficam fora do Git.

> [!CAUTION]
> Copie o `.jks` e a senha para um lugar seguro fora deste computador. Sem eles, publicar atualizações exige um pedido de redefinição da chave ao Google.

---

## 2. Backend em produção

O arquivo `render.yaml` descreve o serviço e o PostgreSQL no Render. Em **Blueprints > New**, aponte para o repositório. O serviço precisa de um plano pago ou de outra hospedagem com HTTPS.

Variáveis obrigatórias (referência completa em `backend/.env.example`):

| Variável | Valor |
|---|---|
| `META_FEITA_ENV` | `production` |
| `META_FEITA_DATABASE_URL` | Conexão PostgreSQL |
| `META_FEITA_PLAY_VALIDATION_MODE` | `google_play` |
| `META_FEITA_GOOGLE_APPLICATION_CREDENTIALS` | JSON da conta de serviço (etapa 5) |
| `META_FEITA_ADMOB_REWARDED_AD_UNITS` | ID numérico do bloco premiado (etapa 3) |
| `META_FEITA_RATE_LIMIT_PROXY_HOPS` | `1` no Render (ver abaixo) |

Confirme que `https://SEU_BACKEND/health` responde `"status":"ok"` e `"env":"production"`.

Se publicar sem PostgreSQL, monte um disco persistente em `/app/data`. Sem isso, os saldos se perdem a cada deploy.

O blueprint também cria a rotina `meta-feita-manutencao`, que a cada 6 horas devolve créditos de reservas travadas e retira os de compras reembolsadas na Google Play. Ela falha de propósito (aparece em vermelho no Render) se o Google Play não estiver configurado em produção. Em outra hospedagem, agende `python -m app.jobs.maintenance` com as mesmas variáveis.

**Confirmar após o primeiro deploy:** o limite de requisições por IP assume que o proxy do Render acrescenta o IP real ao fim de `X-Forwarded-For`. Se várias pessoas aparecerem como o mesmo IP, troque `META_FEITA_RATE_LIMIT_PROXY_HOPS` para `2` (ou `0`, que desativa a leitura do cabeçalho).

---

## 3. AdMob

1. Crie o app Android em [admob.google.com](https://admob.google.com) e anote o **App ID**.
2. Crie um bloco **Banner** e um bloco **Premiado**.
3. No bloco premiado, ative **Verificação no servidor** com a URL `https://SEU_BACKEND/v1/ads/rewarded/ssv`.
4. Em **Privacidade e mensagens**, publique as mensagens de consentimento. Sem mensagem publicada, regiões que exigem consentimento não recebem anúncios.
5. Depois que o app estiver na loja, vincule-o à ficha da Play no AdMob.

---

## 4. Configuração do build

```powershell
Copy-Item config\release.example.json config\release.json
```

Preencha `config/release.json` com a URL do backend e os IDs reais. O arquivo fica fora do Git.

---

## 5. Gerar e enviar o `.aab`

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_release.ps1
```

O script recusa URL sem HTTPS, IDs de teste e valores de exemplo, e roda analyze e testes antes do build. O resultado fica em `build/app/outputs/bundle/release/app-release.aab`.

No [Play Console](https://play.google.com/console):

1. Crie o app **Meta Feita** com pacote `com.feitolabs.meta_feita` e ative o Play App Signing.
2. Envie o `.aab` para **Teste interno**. Os produtos da etapa seguinte só podem ser criados depois disso.
3. Em **Monetizar > Produtos no app**, crie três produtos com os IDs exatos:

| ID do produto | Créditos | Preço |
|---|---|---|
| `meta_feita_credits_10` | 10 | R$ 4,90 |
| `meta_feita_credits_30` | 30 | R$ 11,90 |
| `meta_feita_credits_80` | 80 | R$ 24,90 |

4. Crie a conta de serviço para o backend validar as compras:
   - No Google Cloud, ative a **Google Play Android Developer API**.
   - Crie uma conta de serviço e gere a chave JSON.
   - No Play Console, em **Usuários e permissões**, convide o e-mail da conta com a permissão **Ver dados financeiros**.
   - Coloque o JSON em `META_FEITA_GOOGLE_APPLICATION_CREDENTIALS`.
5. Em **Configurações > Teste de licença**, adicione as contas de teste.

---

## 6. Ficha e formulários

- Textos prontos em `docs/play-store/ficha-da-loja.md`.
- Respostas de privacidade em `docs/play-store/seguranca-de-dados.md`.
- Publique `docs/politica-de-privacidade.html` em uma URL pública, depois de preencher `[DATA_DE_PUBLICACAO]` e `[EMAIL_DE_CONTATO]`.

---

## 7. Roteiro de teste antes de produção

Instale a versão do Teste interno em um aparelho real, com uma conta de teste de licença:

- [ ] O aviso de consentimento aparece, quando aplicável à região.
- [ ] O banner aparece depois de um resultado, e nunca sobre campos.
- [ ] O anúncio premiado até o fim aumenta o saldo em 1 crédito.
- [ ] Fechar o anúncio antes do fim não credita.
- [ ] A compra de teste credita o saldo e o item pode ser comprado de novo.
- [ ] O cancelamento da compra não altera o saldo.
- [ ] Sem internet, as calculadoras funcionam e compras ficam bloqueadas.

---

## 8. Produção

Contas pessoais criadas depois de novembro de 2023 precisam de um **teste fechado com pelo menos 12 testadores por 14 dias contínuos** antes de pedir acesso à produção. Confira a regra vigente no Play Console.

Para cada atualização, aumente o número após o `+` em `version` no `pubspec.yaml` e repita a etapa 5.

---

## Build pelo GitHub Actions (opcional)

Em **Actions > CI > Run workflow**, o job `android-bundle` gera o `.aab` como artefato. Ele exige os secrets:

| Secret | Conteúdo |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | O `.jks` em base64 |
| `ANDROID_KEY_PROPERTIES` | Conteúdo do `key.properties` |
| `ANDROID_RELEASE_JSON` | Conteúdo do `config/release.json` |
