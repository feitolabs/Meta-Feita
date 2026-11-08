from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


LedgerSource = Literal[
    "web_purchase",
    "play_purchase",
    "rewarded_ad",
    "consumption",
    "refund",
]

LedgerStatus = Literal[
    "pending",
    "validated",
    "granted",
    "consumed",
    "reversed",
    "rejected",
]


class CreditPackage(BaseModel):
    productId: str
    credits: int = Field(gt=0)
    title: str
    subtitle: str
    priceCents: int = Field(ge=0)
    displayPrice: str
    highlighted: bool = False
    playProductId: str


class CreditFeatureCost(BaseModel):
    featureId: str
    title: str
    description: str
    creditCost: int = Field(gt=0)


class RewardedAdConfig(BaseModel):
    creditsPerView: int = Field(ge=0)
    dailyLimit: int = Field(ge=1)
    enabled: bool = True


class CatalogResponse(BaseModel):
    catalogVersion: str
    currency: str
    packages: list[CreditPackage]
    features: list[CreditFeatureCost]
    rewardedAd: RewardedAdConfig


class WalletInitResponse(BaseModel):
    walletReference: str
    balance: int
    recoveryCode: str
    lastValidatedAt: str


class WalletRecoverRequest(BaseModel):
    walletReference: str = Field(min_length=8, max_length=128)
    recoveryCode: str = Field(min_length=6, max_length=64)


class WalletBalanceResponse(BaseModel):
    walletReference: str
    balance: int = Field(ge=0)
    lastValidatedAt: str
    catalogVersion: str


class LedgerEntry(BaseModel):
    transactionId: str
    walletReference: str
    source: LedgerSource
    productId: str | None = None
    creditDelta: int
    providerTransactionId: str | None = None
    status: LedgerStatus
    createdAt: str
    idempotencyKey: str


class TransactionsResponse(BaseModel):
    walletReference: str
    balance: int
    transactions: list[LedgerEntry]


class ConsumeCreditsRequest(BaseModel):
    walletReference: str = Field(min_length=8, max_length=128)
    featureId: str = Field(min_length=1, max_length=64)
    idempotencyKey: str = Field(min_length=8, max_length=128)


class ReserveCreditsRequest(BaseModel):
    walletReference: str = Field(min_length=8, max_length=128)
    featureId: str = Field(min_length=1, max_length=64)
    idempotencyKey: str = Field(min_length=8, max_length=128)


class ReservationActionRequest(BaseModel):
    walletReference: str = Field(min_length=8, max_length=128)
    reservationId: str = Field(min_length=8, max_length=128)
    idempotencyKey: str = Field(min_length=8, max_length=128)


class ReservationResponse(BaseModel):
    reservationId: str
    walletReference: str
    featureId: str
    amount: int
    status: Literal["pending", "confirmed", "refunded"]
    balance: int


class CreditOperationResponse(BaseModel):
    transaction: LedgerEntry
    balance: int
    idempotentReplay: bool = False


class WebCheckoutRequest(BaseModel):
    walletReference: str = Field(min_length=8, max_length=128)
    productId: str = Field(min_length=1, max_length=64)


class WebCheckoutResponse(BaseModel):
    checkoutId: str
    walletReference: str
    productId: str
    credits: int
    amountCents: int
    currency: str
    status: Literal["pending"]
    checkoutUrl: str


class WebWebhookEvent(BaseModel):
    eventId: str = Field(min_length=4, max_length=128)
    checkoutId: str = Field(min_length=4, max_length=128)
    walletReference: str = Field(min_length=8, max_length=128)
    productId: str = Field(min_length=1, max_length=64)
    amountCents: int = Field(ge=0)
    currency: str = Field(min_length=3, max_length=3)
    providerTransactionId: str = Field(min_length=4, max_length=128)
    status: Literal["pending", "paid", "cancelled", "rejected", "refunded"]


class PlayPurchaseValidateRequest(BaseModel):
    walletReference: str = Field(min_length=8, max_length=128)
    productId: str = Field(min_length=1, max_length=64)
    purchaseToken: str = Field(min_length=8, max_length=512)
    orderId: str = Field(min_length=4, max_length=128)
    purchaseState: Literal[
        "purchased",
        "pending",
        "cancelled",
        "rejected",
        "refunded",
        "revoked",
        "restored",
    ] = "purchased"
    idempotencyKey: str = Field(min_length=8, max_length=128)


class PlayPurchaseValidateResponse(BaseModel):
    status: LedgerStatus
    acknowledged: bool
    balance: int
    transaction: LedgerEntry
    idempotentReplay: bool = False


class RewardedAdClaimRequest(BaseModel):
    walletReference: str = Field(min_length=8, max_length=128)
    providerTransactionId: str = Field(min_length=8, max_length=128)
    idempotencyKey: str = Field(min_length=8, max_length=128)
    adNetwork: Literal["admob_test", "admob", "web_ads"] = "admob_test"
    signature: str | None = None


FORBIDDEN_TELEMETRY_KEYS = {
    "capital",
    "initialcapital",
    "income",
    "renda",
    "aporte",
    "aportes",
    "contribution",
    "contributions",
    "dividend",
    "dividends",
    "provento",
    "proventos",
    "patrimony",
    "patrimonio",
    "targetvalue",
    "valoralvo",
    "goalvalue",
    "saldo",
    "balance_brl",
    "result_brl",
    "rate_value",
}


class TelemetryEventRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    eventName: Literal[
        "screen_view",
        "flow_started",
        "flow_completed",
        "technical_error",
        "purchase_state",
        "feature_usage",
    ]
    screenName: str | None = Field(default=None, max_length=64)
    platform: Literal["android", "ios", "web", "desktop"] | None = None
    appVersion: str | None = Field(default=None, max_length=32)
    metadata: dict[str, str | int | bool] = Field(default_factory=dict)

    @field_validator("metadata")
    @classmethod
    def ensure_no_financial_data(
        cls, value: dict[str, str | int | bool]
    ) -> dict[str, str | int | bool]:
        for key in value:
            normalized = key.strip().lower().replace("_", "")
            if normalized in FORBIDDEN_TELEMETRY_KEYS or any(
                bad in normalized for bad in ("capital", "renda", "aporte", "dividend", "provento", "patrimon", "goal", "meta_valor")
            ):
                raise ValueError(
                    f"Campo proibido na telemetria operacional: '{key}'. Dados financeiros nunca devem ser enviados."
                )
        return value

