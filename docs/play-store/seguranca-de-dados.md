# Formulários do Play Console — Meta Feita

Respostas baseadas no que o app faz hoje. Se você adicionar outro SDK, revise este arquivo. Confira também a [divulgação de dados do Google Mobile Ads](https://developers.google.com/admob/android/privacy/play-data-disclosure) no momento do preenchimento, porque ela pode mudar.

## Segurança dos dados

| Pergunta | Resposta |
|---|---|
| O app coleta ou compartilha dados do usuário? | Sim |
| Os dados são criptografados em trânsito? | Sim |
| O usuário pode pedir a exclusão dos dados? | Sim, pelo e-mail informado na política de privacidade |

| Tipo de dado | Coletado | Compartilhado | Opcional? | Finalidades | Origem |
|---|---|---|---|---|---|
| Identificadores do dispositivo ou outros IDs (ID de publicidade) | Sim | Sim | Não | Publicidade, análise, prevenção a fraudes | SDK do AdMob |
| Local aproximado (derivado do IP) | Sim | Sim | Não | Publicidade, prevenção a fraudes | SDK do AdMob |
| Interações no app | Sim | Sim | Não | Publicidade, análise | SDK do AdMob |
| Registros de falhas e diagnósticos | Sim | Sim | Não | Análise, prevenção a fraudes | SDK do AdMob |
| Histórico de compras | Sim | Não | Sim | Funcionalidade do app | Servidor de créditos |

Simulações, metas e valores informados **não** devem ser declarados: ficam no aparelho e não saem dele. Dados de cartão **não** são coletados pelo app, porque a Google Play processa o pagamento.

> A versão anterior do guia dizia que o app não coleta dados financeiros. Isso não vale para o formulário: "Histórico de compras" pertence à categoria "Informações financeiras", e o extrato de créditos se enquadra nela.

## Outras declarações

| Formulário | Resposta |
|---|---|
| Anúncios | O app contém anúncios: Sim |
| ID de publicidade | Sim. Finalidades: publicidade, análise e prevenção a fraudes |
| Acesso ao app | Todas as funcionalidades disponíveis sem credenciais |
| Público-alvo | 18 anos ou mais |
| Recursos financeiros | Marque que o app **não** oferece serviços financeiros regulados; é apenas calculadora e simulador |
| Exclusão de conta | O app não tem criação de conta nem login |
| Classificação de conteúdo | Categoria "Referência, notícias ou educativo" ou "Utilitário". Sem violência, sexo, drogas, jogos de azar ou interação entre usuários |
| Política de privacidade | URL pública de `docs/politica-de-privacidade.html` |

## Excluir uma carteira a pedido do usuário

O banco de produção não aceita conexões de fora. No painel do Render, abra o **Shell** do serviço `meta-feita-backend` e rode, com o ID recebido por e-mail:

```bash
python -m app.jobs.delete_wallet ID_DA_CARTEIRA            # só mostra o que seria apagado
python -m app.jobs.delete_wallet ID_DA_CARTEIRA --confirm  # apaga de verdade
```
