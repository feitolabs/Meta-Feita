from __future__ import annotations

import threading
from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager

from fastapi import FastAPI, Header, HTTPException, Request, Response
from fastapi import Path as ApiPath
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .catalog import load_catalog
from .config import Settings, get_settings
from .database import create_database
from .models import (
    CatalogResponse,
    ConsumeCreditsRequest,
    CreditOperationResponse,
    PlayPurchaseValidateRequest,
    PlayPurchaseValidateResponse,
    ReservationActionRequest,
    ReservationResponse,
    ReserveCreditsRequest,
    RewardedAdClaimRequest,
    TelemetryEventRequest,
    TransactionsResponse,
    WalletBalanceResponse,
    WalletInitResponse,
    WalletRecoverRequest,
    WebCheckoutRequest,
    WebCheckoutResponse,
    WebWebhookEvent,
)
from .rate_limit import SlidingWindowRateLimiter
from .services.admob_ssv import AdmobSsvVerifier, SsvKeysUnavailable, SsvVerificationError
from .services.credit_service import CreditService, DomainError
from .services.play_verifier import GooglePlayDeveloperVerifier, PlayVerifier


# Chamadas de servidores do Google e do provedor de pagamento não entram no limite.
RATE_LIMIT_EXEMPT_PATHS = {
    "/health",
    "/v1/ads/rewarded/ssv",
    "/v1/purchases/web/webhook",
}
# Limites por IP generosos: operadoras móveis compartilham IP entre muitos aparelhos.
RATE_LIMIT_PER_PATH = {
    "/v1/wallets/recover": (20, 60.0),
    "/v1/wallets/init": (60, 60.0),
}
RATE_LIMIT_DEFAULT = (600, 60.0)
RECOVERY_LIMIT_PER_WALLET = (10, 900.0)

RATE_LIMITED_MESSAGE = "Muitas tentativas em pouco tempo. Aguarde e tente novamente."


def _client_address(request: Request, proxy_hops: int) -> str:
    """IP de quem chamou. Com proxies confiáveis, vale o N-ésimo da direita em X-Forwarded-For.

    O proxy acrescenta o IP real ao final da lista; entradas à esquerda podem ter sido
    forjadas pelo cliente e nunca são usadas.
    """
    if proxy_hops > 0:
        hops = [h.strip() for h in request.headers.get("x-forwarded-for", "").split(",") if h.strip()]
        if len(hops) >= proxy_hops:
            return hops[-proxy_hops]
    return request.client.host if request.client else "unknown"


def _wallet_path() -> str:
    return ApiPath(min_length=1, max_length=128, pattern=r"^[A-Za-z0-9_.:\-]+$")


def _build_play_verifier(cfg: Settings) -> PlayVerifier | None:
    if cfg.play_validation_mode == "google_play" and cfg.google_application_credentials:
        return GooglePlayDeveloperVerifier(
            package_name=cfg.play_package_name,
            credentials_source=cfg.google_application_credentials,
        )
    return None


def create_app(
    settings: Settings | None = None,
    play_verifier: PlayVerifier | None = None,
    ssv_verifier: AdmobSsvVerifier | None = None,
) -> FastAPI:
    cfg = settings or get_settings()
    catalog = load_catalog(cfg.catalog_path)
    db = create_database(cfg.database_path, cfg.database_url)
    service = CreditService(
        db=db,
        catalog=catalog,
        settings=cfg,
        play_verifier=play_verifier or _build_play_verifier(cfg),
    )
    verifier = ssv_verifier or AdmobSsvVerifier()
    limiter = SlidingWindowRateLimiter()

    is_production = cfg.env == "production"

    @asynccontextmanager
    async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
        if ssv_verifier is None and cfg.admob_rewarded_ad_unit_set:
            threading.Thread(target=verifier.prefetch, daemon=True).start()
        yield
        db.close()

    app = FastAPI(
        lifespan=lifespan,
        title="Meta Feita · Monetização API",
        version="1.0.0",
        description="Backend mínimo exclusivo para catálogo, compras, anúncios recompensados e ledger de créditos.",
        docs_url=None if is_production else "/docs",
        redoc_url=None if is_production else "/redoc",
        openapi_url=None if is_production else "/openapi.json",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=cfg.cors_origin_list,
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )

    app.state.settings = cfg
    app.state.catalog = catalog
    app.state.db = db
    app.state.credit_service = service

    def rate_limited_response() -> JSONResponse:
        return JSONResponse(
            status_code=429,
            content={"code": "RATE_LIMITED", "message": RATE_LIMITED_MESSAGE},
        )

    @app.middleware("http")
    async def enforce_rate_limit(
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        path = request.url.path
        if not cfg.rate_limit_enabled or path in RATE_LIMIT_EXEMPT_PATHS:
            return await call_next(request)
        limit, window = RATE_LIMIT_PER_PATH.get(path, RATE_LIMIT_DEFAULT)
        address = _client_address(request, cfg.rate_limit_proxy_hops)
        bucket = path if path in RATE_LIMIT_PER_PATH else "*"
        if not limiter.allow(f"ip:{bucket}:{address}", limit, window):
            return rate_limited_response()
        return await call_next(request)

    @app.exception_handler(DomainError)
    async def domain_error_handler(_request: Request, exc: DomainError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"code": exc.code, "message": exc.message},
        )

    for integrity_error in db.integrity_errors:
        # Duas requisições simultâneas com o mesmo identificador: a segunda repete e vira replay.
        @app.exception_handler(integrity_error)
        async def integrity_error_handler(_request: Request, _exc: Exception) -> JSONResponse:
            return JSONResponse(
                status_code=409,
                content={"code": "CONFLICT_RETRY", "message": "Operação concorrente. Tente novamente."},
            )

    @app.get("/health")
    def health() -> dict[str, str]:
        return {
            "status": "ok",
            "service": "meta-feita-monetization",
            "env": cfg.env,
            "catalogVersion": catalog.catalogVersion,
        }

    @app.get("/v1/catalog", response_model=CatalogResponse)
    def get_catalog() -> CatalogResponse:
        return catalog

    @app.post("/v1/wallets/init", response_model=WalletInitResponse, status_code=201)
    def init_wallet() -> WalletInitResponse:
        return service.init_wallet()

    @app.post("/v1/wallets/recover", response_model=WalletBalanceResponse)
    def recover_wallet(payload: WalletRecoverRequest) -> WalletBalanceResponse:
        limit, window = RECOVERY_LIMIT_PER_WALLET
        if cfg.rate_limit_enabled and not limiter.allow(
            f"recover:{payload.walletReference}", limit, window
        ):
            raise DomainError("RATE_LIMITED", RATE_LIMITED_MESSAGE, 429)
        return service.recover_wallet(payload.walletReference, payload.recoveryCode)

    @app.get("/v1/wallets/{wallet_reference}/balance", response_model=WalletBalanceResponse)
    def get_balance(wallet_reference: str = _wallet_path()) -> WalletBalanceResponse:
        return service.get_balance(wallet_reference)

    @app.get("/v1/wallets/{wallet_reference}/transactions", response_model=TransactionsResponse)
    def list_transactions(
        wallet_reference: str = _wallet_path(), limit: int = 50
    ) -> TransactionsResponse:
        return service.list_transactions(wallet_reference, limit=limit)

    @app.post("/v1/credits/consume", response_model=CreditOperationResponse)
    def consume_credits(payload: ConsumeCreditsRequest) -> CreditOperationResponse:
        return service.consume_credits(
            wallet_reference=payload.walletReference,
            feature_id=payload.featureId,
            idempotency_key=payload.idempotencyKey,
        )

    @app.post("/v1/credits/reserve", response_model=ReservationResponse)
    def reserve_credits(payload: ReserveCreditsRequest) -> ReservationResponse:
        return service.reserve_credits(
            wallet_reference=payload.walletReference,
            feature_id=payload.featureId,
            idempotency_key=payload.idempotencyKey,
        )

    @app.post("/v1/credits/confirm", response_model=ReservationResponse)
    def confirm_reservation(payload: ReservationActionRequest) -> ReservationResponse:
        return service.confirm_reservation(
            wallet_reference=payload.walletReference,
            reservation_id=payload.reservationId,
            idempotency_key=payload.idempotencyKey,
        )

    @app.post("/v1/credits/refund", response_model=ReservationResponse)
    def refund_reservation(payload: ReservationActionRequest) -> ReservationResponse:
        return service.refund_reservation(
            wallet_reference=payload.walletReference,
            reservation_id=payload.reservationId,
            idempotency_key=payload.idempotencyKey,
        )

    @app.post("/v1/purchases/web/checkout", response_model=WebCheckoutResponse, status_code=201)
    def create_web_checkout(payload: WebCheckoutRequest) -> WebCheckoutResponse:
        return service.create_web_checkout(payload.walletReference, payload.productId)

    @app.post("/v1/purchases/web/webhook", response_model=CreditOperationResponse)
    async def handle_web_webhook(
        request: Request,
        x_webhook_signature: str | None = Header(default=None),
    ) -> CreditOperationResponse:
        raw_body = await request.body()
        try:
            event = WebWebhookEvent.model_validate_json(raw_body)
        except Exception as exc:
            raise HTTPException(status_code=422, detail=f"Payload de webhook inválido: {exc}") from exc
        return service.process_web_webhook(raw_body, x_webhook_signature, event)

    @app.post("/v1/purchases/play/validate", response_model=PlayPurchaseValidateResponse)
    def validate_play_purchase(payload: PlayPurchaseValidateRequest) -> PlayPurchaseValidateResponse:
        return service.validate_play_purchase(payload)

    @app.post("/v1/ads/rewarded/claim", response_model=CreditOperationResponse)
    def claim_rewarded_ad(payload: RewardedAdClaimRequest) -> CreditOperationResponse:
        return service.claim_rewarded_ad(payload)

    @app.get("/v1/ads/rewarded/ssv")
    def admob_ssv_callback(request: Request) -> dict[str, str]:
        try:
            params = verifier.verify(request.scope.get("query_string", b""))
        except SsvVerificationError as exc:
            raise DomainError("INVALID_AD_SIGNATURE", "Assinatura de recompensa inválida.", 401) from exc
        except SsvKeysUnavailable as exc:
            raise DomainError("AD_KEYS_UNAVAILABLE", "Verificação temporariamente indisponível.", 503) from exc
        return service.process_admob_ssv(params)

    @app.post("/v1/telemetry/events", status_code=202)
    def record_telemetry(payload: TelemetryEventRequest) -> dict[str, str]:
        return service.record_telemetry(payload)

    return app


app = create_app()
