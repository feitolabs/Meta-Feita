# Meta Feita (Feito Labs)

Aplicativo de simulação e planejamento financeiro com persistência exclusivamente local no dispositivo (`localstorage`), motores matemáticos determinísticos em precisão decimal e backend mínimo em Python apenas para monetização (créditos, compras e validação de anúncios recompensados).

> **Aviso:** Resultados são simulações matemáticas baseadas nas premissas informadas pelo usuário. Não constituem recomendação de investimento nem garantia de rentabilidade.

## Estrutura do Projeto

- `app/` — Frontend multiplataforma em **Flutter** (Android, iOS e Web responsivo) seguindo o design system Petróleo & Brasa e as telas de protótipo em `CONTEXTOS/Meta Feita · App.pdf`.
- `backend/` — Backend mínimo de monetização em **Python (FastAPI + SQLite)** com ledger idempotente de créditos. Nunca recebe dados financeiros das simulações ou metas do usuário.
- `CONTEXTOS/` — Especificações originais, pacote de ícones, paleta de cores e protótipo de referência.
- `DECISIONS.md` — Registro das decisões técnicas, bibliotecas adotadas e resolução de pendências de MVP.

## Como executar localmente

### 1. Backend Python (`backend/`)
```bash
cd backend
cp .env.example .env
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Testes do backend:
```bash
cd backend
python -m pytest -v
```

### 2. Frontend Flutter (`app/`)
```bash
cd app
flutter pub get
flutter analyze
flutter test -r expanded
flutter build web
flutter run -d edge --dart-define=API_BASE_URL=http://localhost:8000
```

Para Android / iOS, configure `API_BASE_URL` via `--dart-define=API_BASE_URL=https://sua-api.exemplo` sem embutir segredos no cliente.
