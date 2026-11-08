from __future__ import annotations

from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .catalog import load_catalog
from .config import Settings, get_settings
from .database import Database
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
from .services.credit_service import CreditService, DomainError


def create_app(settings: Settings | None = None) -> FastAPI:
    cfg = settings or get_settings()
    catalog = load_catalog(cfg.catalog_path)
    db = Database(cfg.database_path)
    service = CreditService(db=db, catalog=catalog, settings=cfg)

    app = FastAPI(
        title="Meta Feita · Monetização API",
        version="1.0.0",
        description="Backend mínimo exclusivo para catálogo, compras, anúncios recompensados e ledger de créditos.",
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

    @app.exception_handler(DomainError)
    async def domain_error_handler(_request: Request, exc: DomainError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"code": exc.code, "message": exc.message},
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
        return service.recover_wallet(payload.walletReference, payload.recoveryCode)

    @app.get("/v1/wallets/{wallet_reference}/balance", response_model=WalletBalanceResponse)
    def get_balance(wallet_reference: str) -> WalletBalanceResponse:
        return service.get_balance(wallet_reference)

    @app.get("/v1/wallets/{wallet_reference}/transactions", response_model=TransactionsResponse)
    def list_transactions(wallet_reference: str, limit: int = 50) -> TransactionsResponse:
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

    @app.post("/v1/telemetry/events", status_code=202)
    def record_telemetry(payload: TelemetryEventRequest) -> dict[str, str]:
        return service.record_telemetry(payload)

    return app


app = create_app()

