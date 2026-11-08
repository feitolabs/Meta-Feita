from __future__ import annotations

import json
import sqlite3
import uuid
from datetime import datetime, timezone

from ..config import Settings
from ..database import Database
from ..models import (
    CatalogResponse,
    CreditFeatureCost,
    CreditOperationResponse,
    CreditPackage,
    LedgerEntry,
    PlayPurchaseValidateRequest,
    PlayPurchaseValidateResponse,
    ReservationResponse,
    RewardedAdClaimRequest,
    TelemetryEventRequest,
    TransactionsResponse,
    WalletBalanceResponse,
    WalletInitResponse,
    WebCheckoutResponse,
    WebWebhookEvent,
)
from ..security import generate_recovery_code, verify_recovery_code, verify_webhook_signature


class DomainError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _row_to_ledger(row: sqlite3.Row) -> LedgerEntry:
    return LedgerEntry(
        transactionId=row["transaction_id"],
        walletReference=row["wallet_reference"],
        source=row["source"],
        productId=row["product_id"],
        creditDelta=row["credit_delta"],
        providerTransactionId=row["provider_transaction_id"],
        status=row["status"],
        createdAt=row["created_at"],
        idempotencyKey=row["idempotency_key"],
    )


class CreditService:
    def __init__(
        self,
        db: Database,
        catalog: CatalogResponse,
        settings: Settings,
    ) -> None:
        self.db = db
        self.catalog = catalog
        self.settings = settings

    def _get_package(self, product_id: str) -> CreditPackage:
        for pkg in self.catalog.packages:
            if pkg.productId == product_id or pkg.playProductId == product_id:
                return pkg
        raise DomainError("PRODUCT_NOT_FOUND", f"Pacote '{product_id}' não encontrado no catálogo.", 404)

    def _get_feature(self, feature_id: str) -> CreditFeatureCost:
        for feature in self.catalog.features:
            if feature.featureId == feature_id:
                return feature
        raise DomainError("FEATURE_NOT_FOUND", f"Recurso '{feature_id}' não encontrado no catálogo.", 404)

    def _require_wallet(self, conn: sqlite3.Connection, wallet_reference: str) -> sqlite3.Row:
        row = conn.execute(
            "SELECT * FROM wallets WHERE wallet_reference = ?",
            (wallet_reference,),
        ).fetchone()
        if row is None:
            raise DomainError("WALLET_NOT_FOUND", "Carteira não encontrada.", 404)
        return row

    def init_wallet(self) -> WalletInitResponse:
        now = _utc_now_iso()
        wallet_ref = f"mf_w_{uuid.uuid4().hex}"
        code, salt, digest = generate_recovery_code()
        with self.db.transaction() as conn:
            conn.execute(
                """
                INSERT INTO wallets (
                    wallet_reference, recovery_code_hash, recovery_salt,
                    balance, created_at, updated_at
                ) VALUES (?, ?, ?, 0, ?, ?)
                """,
                (wallet_ref, digest, salt, now, now),
            )
        return WalletInitResponse(
            walletReference=wallet_ref,
            balance=0,
            recoveryCode=code,
            lastValidatedAt=now,
        )

    def recover_wallet(self, wallet_reference: str, recovery_code: str) -> WalletBalanceResponse:
        with self.db.read() as conn:
            wallet = self._require_wallet(conn, wallet_reference)
            if not verify_recovery_code(
                recovery_code, wallet["recovery_salt"], wallet["recovery_code_hash"]
            ):
                raise DomainError(
                    "INVALID_RECOVERY_CODE",
                    "Código de recuperação inválido para esta carteira.",
                    401,
                )
            return WalletBalanceResponse(
                walletReference=wallet["wallet_reference"],
                balance=wallet["balance"],
                lastValidatedAt=_utc_now_iso(),
                catalogVersion=self.catalog.catalogVersion,
            )

    def get_balance(self, wallet_reference: str) -> WalletBalanceResponse:
        with self.db.read() as conn:
            wallet = self._require_wallet(conn, wallet_reference)
            return WalletBalanceResponse(
                walletReference=wallet["wallet_reference"],
                balance=wallet["balance"],
                lastValidatedAt=_utc_now_iso(),
                catalogVersion=self.catalog.catalogVersion,
            )

    def list_transactions(self, wallet_reference: str, limit: int = 50) -> TransactionsResponse:
        with self.db.read() as conn:
            wallet = self._require_wallet(conn, wallet_reference)
            rows = conn.execute(
                """
                SELECT * FROM credit_ledger
                WHERE wallet_reference = ?
                ORDER BY created_at DESC, rowid DESC
                LIMIT ?
                """,
                (wallet_reference, max(1, min(limit, 200))),
            ).fetchall()
            return TransactionsResponse(
                walletReference=wallet_reference,
                balance=wallet["balance"],
                transactions=[_row_to_ledger(r) for r in rows],
            )

    def consume_credits(
        self,
        wallet_reference: str,
        feature_id: str,
        idempotency_key: str,
    ) -> CreditOperationResponse:
        feature = self._get_feature(feature_id)
        now = _utc_now_iso()
        with self.db.transaction() as conn:
            wallet = self._require_wallet(conn, wallet_reference)
            existing = conn.execute(
                """
                SELECT * FROM credit_ledger
                WHERE wallet_reference = ? AND idempotency_key = ?
                """,
                (wallet_reference, idempotency_key),
            ).fetchone()
            if existing is not None:
                return CreditOperationResponse(
                    transaction=_row_to_ledger(existing),
                    balance=wallet["balance"],
                    idempotentReplay=True,
                )

            if wallet["balance"] < feature.creditCost:
                raise DomainError(
                    "INSUFFICIENT_CREDITS",
                    f"Saldo insuficiente. Este recurso custa {feature.creditCost} créditos e seu saldo é {wallet['balance']}.",
                    402,
                )

            new_balance = wallet["balance"] - feature.creditCost
            tx_id = f"tx_{uuid.uuid4().hex}"
            conn.execute(
                "UPDATE wallets SET balance = ?, updated_at = ? WHERE wallet_reference = ?",
                (new_balance, now, wallet_reference),
            )
            conn.execute(
                """
                INSERT INTO credit_ledger (
                    transaction_id, wallet_reference, source, product_id,
                    credit_delta, provider_transaction_id, status,
                    created_at, idempotency_key, reservation_id
                ) VALUES (?, ?, 'consumption', ?, ?, NULL, 'consumed', ?, ?, NULL)
                """,
                (tx_id, wallet_reference, feature.featureId, -feature.creditCost, now, idempotency_key),
            )
            created = conn.execute(
                "SELECT * FROM credit_ledger WHERE transaction_id = ?",
                (tx_id,),
            ).fetchone()
            return CreditOperationResponse(
                transaction=_row_to_ledger(created),
                balance=new_balance,
                idempotentReplay=False,
            )

    def reserve_credits(
        self,
        wallet_reference: str,
        feature_id: str,
        idempotency_key: str,
    ) -> ReservationResponse:
        feature = self._get_feature(feature_id)
        now = _utc_now_iso()
        with self.db.transaction() as conn:
            wallet = self._require_wallet(conn, wallet_reference)
            existing = conn.execute(
                """
                SELECT * FROM reservations
                WHERE wallet_reference = ? AND idempotency_key = ?
                """,
                (wallet_reference, idempotency_key),
            ).fetchone()
            if existing is not None:
                return ReservationResponse(
                    reservationId=existing["reservation_id"],
                    walletReference=wallet_reference,
                    featureId=existing["feature_id"],
                    amount=existing["amount"],
                    status=existing["status"],
                    balance=wallet["balance"],
                )

            if wallet["balance"] < feature.creditCost:
                raise DomainError(
                    "INSUFFICIENT_CREDITS",
                    f"Saldo insuficiente para reservar {feature.creditCost} créditos.",
                    402,
                )

            new_balance = wallet["balance"] - feature.creditCost
            res_id = f"res_{uuid.uuid4().hex}"
            tx_id = f"tx_{uuid.uuid4().hex}"
            conn.execute(
                "UPDATE wallets SET balance = ?, updated_at = ? WHERE wallet_reference = ?",
                (new_balance, now, wallet_reference),
            )
            conn.execute(
                """
                INSERT INTO reservations (
                    reservation_id, wallet_reference, feature_id, amount,
                    status, idempotency_key, created_at, updated_at
                ) VALUES (?, ?, ?, ?, 'pending', ?, ?, ?)
                """,
                (res_id, wallet_reference, feature.featureId, feature.creditCost, idempotency_key, now, now),
            )
            conn.execute(
                """
                INSERT INTO credit_ledger (
                    transaction_id, wallet_reference, source, product_id,
                    credit_delta, provider_transaction_id, status,
                    created_at, idempotency_key, reservation_id
                ) VALUES (?, ?, 'consumption', ?, ?, NULL, 'pending', ?, ?, ?)
                """,
                (tx_id, wallet_reference, feature.featureId, -feature.creditCost, now, idempotency_key, res_id),
            )
            return ReservationResponse(
                reservationId=res_id,
                walletReference=wallet_reference,
                featureId=feature.featureId,
                amount=feature.creditCost,
                status="pending",
                balance=new_balance,
            )

    def confirm_reservation(
        self,
        wallet_reference: str,
        reservation_id: str,
        idempotency_key: str,
    ) -> ReservationResponse:
        now = _utc_now_iso()
        with self.db.transaction() as conn:
            wallet = self._require_wallet(conn, wallet_reference)
            res = conn.execute(
                """
                SELECT * FROM reservations
                WHERE reservation_id = ? AND wallet_reference = ?
                """,
                (reservation_id, wallet_reference),
            ).fetchone()
            if res is None:
                raise DomainError("RESERVATION_NOT_FOUND", "Reserva não encontrada.", 404)
            if res["status"] == "refunded":
                raise DomainError("RESERVATION_ALREADY_REFUNDED", "Reserva já foi estornada.", 409)
            if res["status"] == "pending":
                conn.execute(
                    "UPDATE reservations SET status = 'confirmed', updated_at = ? WHERE reservation_id = ?",
                    (now, reservation_id),
                )
                conn.execute(
                    "UPDATE credit_ledger SET status = 'consumed' WHERE reservation_id = ? AND source = 'consumption'",
                    (reservation_id,),
                )
            return ReservationResponse(
                reservationId=reservation_id,
                walletReference=wallet_reference,
                featureId=res["feature_id"],
                amount=res["amount"],
                status="confirmed",
                balance=wallet["balance"],
            )

    def refund_reservation(
        self,
        wallet_reference: str,
        reservation_id: str,
        idempotency_key: str,
    ) -> ReservationResponse:
        now = _utc_now_iso()
        with self.db.transaction() as conn:
            wallet = self._require_wallet(conn, wallet_reference)
            res = conn.execute(
                """
                SELECT * FROM reservations
                WHERE reservation_id = ? AND wallet_reference = ?
                """,
                (reservation_id, wallet_reference),
            ).fetchone()
            if res is None:
                raise DomainError("RESERVATION_NOT_FOUND", "Reserva não encontrada.", 404)

            if res["status"] == "refunded":
                return ReservationResponse(
                    reservationId=reservation_id,
                    walletReference=wallet_reference,
                    featureId=res["feature_id"],
                    amount=res["amount"],
                    status="refunded",
                    balance=wallet["balance"],
                )

            new_balance = wallet["balance"] + res["amount"]
            refund_tx_id = f"tx_{uuid.uuid4().hex}"
            conn.execute(
                "UPDATE wallets SET balance = ?, updated_at = ? WHERE wallet_reference = ?",
                (new_balance, now, wallet_reference),
            )
            conn.execute(
                "UPDATE reservations SET status = 'refunded', updated_at = ? WHERE reservation_id = ?",
                (now, reservation_id),
            )
            conn.execute(
                "UPDATE credit_ledger SET status = 'reversed' WHERE reservation_id = ? AND source = 'consumption'",
                (reservation_id,),
            )
            conn.execute(
                """
                INSERT INTO credit_ledger (
                    transaction_id, wallet_reference, source, product_id,
                    credit_delta, provider_transaction_id, status,
                    created_at, idempotency_key, reservation_id
                ) VALUES (?, ?, 'refund', ?, ?, NULL, 'reversed', ?, ?, ?)
                """,
                (
                    refund_tx_id,
                    wallet_reference,
                    res["feature_id"],
                    res["amount"],
                    now,
                    f"refund:{reservation_id}:{idempotency_key}",
                    reservation_id,
                ),
            )
            return ReservationResponse(
                reservationId=reservation_id,
                walletReference=wallet_reference,
                featureId=res["feature_id"],
                amount=res["amount"],
                status="refunded",
                balance=new_balance,
            )

    def create_web_checkout(self, wallet_reference: str, product_id: str) -> WebCheckoutResponse:
        pkg = self._get_package(product_id)
        now = _utc_now_iso()
        checkout_id = f"chk_{uuid.uuid4().hex}"
        with self.db.transaction() as conn:
            self._require_wallet(conn, wallet_reference)
            conn.execute(
                """
                INSERT INTO web_checkouts (
                    checkout_id, wallet_reference, product_id,
                    expected_amount_cents, currency, status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?)
                """,
                (
                    checkout_id,
                    wallet_reference,
                    pkg.productId,
                    pkg.priceCents,
                    self.catalog.currency,
                    now,
                    now,
                ),
            )
        return WebCheckoutResponse(
            checkoutId=checkout_id,
            walletReference=wallet_reference,
            productId=pkg.productId,
            credits=pkg.credits,
            amountCents=pkg.priceCents,
            currency=self.catalog.currency,
            status="pending",
            checkoutUrl=f"/checkout/web/{checkout_id}",
        )

    def process_web_webhook(
        self,
        raw_body: bytes,
        signature_header: str | None,
        event: WebWebhookEvent,
    ) -> CreditOperationResponse:
        if not verify_webhook_signature(
            raw_body,
            signature_header,
            self.settings.web_webhook_secret,
        ):
            raise DomainError("INVALID_WEBHOOK_SIGNATURE", "Assinatura do webhook inválida ou não configurada.", 401)

        pkg = self._get_package(event.productId)
        now = _utc_now_iso()
        with self.db.transaction() as conn:
            wallet = self._require_wallet(conn, event.walletReference)
            checkout = conn.execute(
                "SELECT * FROM web_checkouts WHERE checkout_id = ?",
                (event.checkoutId,),
            ).fetchone()
            if checkout is None:
                raise DomainError("CHECKOUT_NOT_FOUND", "Sessão de checkout não encontrada.", 404)
            if checkout["wallet_reference"] != event.walletReference:
                raise DomainError("WALLET_MISMATCH", "Carteira não corresponde ao checkout.", 400)
            if checkout["product_id"] != pkg.productId:
                raise DomainError("PRODUCT_MISMATCH", "Produto diverge do checkout original.", 400)
            if (
                event.amountCents != checkout["expected_amount_cents"]
                or event.currency.upper() != checkout["currency"].upper()
            ):
                raise DomainError("AMOUNT_OR_CURRENCY_MISMATCH", "Valor ou moeda diverge do catálogo.", 400)

            existing = conn.execute(
                """
                SELECT * FROM credit_ledger
                WHERE source = 'web_purchase' AND provider_transaction_id = ?
                """,
                (event.providerTransactionId,),
            ).fetchone()

            if event.status == "paid":
                if existing is not None:
                    return CreditOperationResponse(
                        transaction=_row_to_ledger(existing),
                        balance=wallet["balance"],
                        idempotentReplay=True,
                    )
                new_balance = wallet["balance"] + pkg.credits
                tx_id = f"tx_{uuid.uuid4().hex}"
                conn.execute(
                    "UPDATE wallets SET balance = ?, updated_at = ? WHERE wallet_reference = ?",
                    (new_balance, now, wallet["wallet_reference"]),
                )
                conn.execute(
                    "UPDATE web_checkouts SET status = 'paid', updated_at = ? WHERE checkout_id = ?",
                    (now, event.checkoutId),
                )
                conn.execute(
                    """
                    INSERT INTO credit_ledger (
                        transaction_id, wallet_reference, source, product_id,
                        credit_delta, provider_transaction_id, status,
                        created_at, idempotency_key, reservation_id
                    ) VALUES (?, ?, 'web_purchase', ?, ?, ?, 'granted', ?, ?, NULL)
                    """,
                    (
                        tx_id,
                        wallet["wallet_reference"],
                        pkg.productId,
                        pkg.credits,
                        event.providerTransactionId,
                        now,
                        f"web:{event.eventId}",
                    ),
                )
                row = conn.execute(
                    "SELECT * FROM credit_ledger WHERE transaction_id = ?",
                    (tx_id,),
                ).fetchone()
                return CreditOperationResponse(
                    transaction=_row_to_ledger(row),
                    balance=new_balance,
                    idempotentReplay=False,
                )

            if event.status == "refunded":
                refund_key = f"web_refund:{event.providerTransactionId}"
                existing_refund = conn.execute(
                    """
                    SELECT * FROM credit_ledger
                    WHERE wallet_reference = ? AND idempotency_key = ?
                    """,
                    (wallet["wallet_reference"], refund_key),
                ).fetchone()
                if existing_refund is not None:
                    return CreditOperationResponse(
                        transaction=_row_to_ledger(existing_refund),
                        balance=wallet["balance"],
                        idempotentReplay=True,
                    )
                deduct = min(wallet["balance"], pkg.credits)
                new_balance = wallet["balance"] - deduct
                tx_id = f"tx_{uuid.uuid4().hex}"
                conn.execute(
                    "UPDATE wallets SET balance = ?, updated_at = ? WHERE wallet_reference = ?",
                    (new_balance, now, wallet["wallet_reference"]),
                )
                conn.execute(
                    "UPDATE web_checkouts SET status = 'refunded', updated_at = ? WHERE checkout_id = ?",
                    (now, event.checkoutId),
                )
                conn.execute(
                    """
                    INSERT INTO credit_ledger (
                        transaction_id, wallet_reference, source, product_id,
                        credit_delta, provider_transaction_id, status,
                        created_at, idempotency_key, reservation_id
                    ) VALUES (?, ?, 'refund', ?, ?, ?, 'reversed', ?, ?, NULL)
                    """,
                    (
                        tx_id,
                        wallet["wallet_reference"],
                        pkg.productId,
                        -deduct,
                        f"refund:{event.providerTransactionId}",
                        now,
                        refund_key,
                    ),
                )
                row = conn.execute(
                    "SELECT * FROM credit_ledger WHERE transaction_id = ?",
                    (tx_id,),
                ).fetchone()
                return CreditOperationResponse(
                    transaction=_row_to_ledger(row),
                    balance=new_balance,
                    idempotentReplay=False,
                )

            # pending, cancelled, rejected -> registra sem conceder créditos
            mapped_checkout_status = "failed" if event.status == "rejected" else event.status
            conn.execute(
                "UPDATE web_checkouts SET status = ?, updated_at = ? WHERE checkout_id = ?",
                (mapped_checkout_status, now, event.checkoutId),
            )
            tx_id = f"tx_{uuid.uuid4().hex}"
            idem = f"web_state:{event.eventId}:{event.status}"
            existing_state = conn.execute(
                "SELECT * FROM credit_ledger WHERE wallet_reference = ? AND idempotency_key = ?",
                (wallet["wallet_reference"], idem),
            ).fetchone()
            if existing_state is not None:
                return CreditOperationResponse(
                    transaction=_row_to_ledger(existing_state),
                    balance=wallet["balance"],
                    idempotentReplay=True,
                )
            ledger_status = "pending" if event.status == "pending" else "rejected"
            conn.execute(
                """
                INSERT INTO credit_ledger (
                    transaction_id, wallet_reference, source, product_id,
                    credit_delta, provider_transaction_id, status,
                    created_at, idempotency_key, reservation_id
                ) VALUES (?, ?, 'web_purchase', ?, 0, NULL, ?, ?, ?, NULL)
                """,
                (tx_id, wallet["wallet_reference"], pkg.productId, ledger_status, now, idem),
            )
            row = conn.execute("SELECT * FROM credit_ledger WHERE transaction_id = ?", (tx_id,)).fetchone()
            return CreditOperationResponse(
                transaction=_row_to_ledger(row),
                balance=wallet["balance"],
                idempotentReplay=False,
            )

    def validate_play_purchase(
        self, req: PlayPurchaseValidateRequest
    ) -> PlayPurchaseValidateResponse:
        if self.settings.play_validation_mode == "disabled":
            raise DomainError(
                "PLAY_BILLING_DISABLED",
                "Validação Google Play Billing não configurada neste ambiente.",
                503,
            )

        if self.settings.play_validation_mode == "google_play" and not self.settings.google_application_credentials:
            raise DomainError(
                "PLAY_CREDENTIALS_MISSING",
                "Credenciais de conta de serviço Google Play ausentes no ambiente.",
                503,
            )

        pkg = self._get_package(req.productId)
        now = _utc_now_iso()
        with self.db.transaction() as conn:
            wallet = self._require_wallet(conn, req.walletReference)

            if req.purchaseState in ("purchased", "restored"):
                existing_token = conn.execute(
                    """
                    SELECT * FROM credit_ledger
                    WHERE source = 'play_purchase' AND provider_transaction_id = ?
                    """,
                    (req.purchaseToken,),
                ).fetchone()
                if existing_token is not None:
                    return PlayPurchaseValidateResponse(
                        status=existing_token["status"],
                        acknowledged=True,
                        balance=wallet["balance"],
                        transaction=_row_to_ledger(existing_token),
                        idempotentReplay=True,
                    )

                existing_idem = conn.execute(
                    """
                    SELECT * FROM credit_ledger
                    WHERE wallet_reference = ? AND idempotency_key = ?
                    """,
                    (req.walletReference, req.idempotencyKey),
                ).fetchone()
                if existing_idem is not None:
                    return PlayPurchaseValidateResponse(
                        status=existing_idem["status"],
                        acknowledged=True,
                        balance=wallet["balance"],
                        transaction=_row_to_ledger(existing_idem),
                        idempotentReplay=True,
                    )

                new_balance = wallet["balance"] + pkg.credits
                tx_id = f"tx_{uuid.uuid4().hex}"
                conn.execute(
                    "UPDATE wallets SET balance = ?, updated_at = ? WHERE wallet_reference = ?",
                    (new_balance, now, req.walletReference),
                )
                conn.execute(
                    """
                    INSERT INTO credit_ledger (
                        transaction_id, wallet_reference, source, product_id,
                        credit_delta, provider_transaction_id, status,
                        created_at, idempotency_key, reservation_id
                    ) VALUES (?, ?, 'play_purchase', ?, ?, ?, 'granted', ?, ?, NULL)
                    """,
                    (
                        tx_id,
                        req.walletReference,
                        pkg.productId,
                        pkg.credits,
                        req.purchaseToken,
                        now,
                        req.idempotencyKey,
                    ),
                )
                row = conn.execute("SELECT * FROM credit_ledger WHERE transaction_id = ?", (tx_id,)).fetchone()
                return PlayPurchaseValidateResponse(
                    status="granted",
                    acknowledged=True,
                    balance=new_balance,
                    transaction=_row_to_ledger(row),
                    idempotentReplay=False,
                )

            if req.purchaseState in ("refunded", "revoked"):
                rev_key = f"play_revoked:{req.purchaseToken}"
                existing_rev = conn.execute(
                    """
                    SELECT * FROM credit_ledger
                    WHERE wallet_reference = ? AND idempotency_key = ?
                    """,
                    (req.walletReference, rev_key),
                ).fetchone()
                if existing_rev is not None:
                    return PlayPurchaseValidateResponse(
                        status="reversed",
                        acknowledged=False,
                        balance=wallet["balance"],
                        transaction=_row_to_ledger(existing_rev),
                        idempotentReplay=True,
                    )

                granted = conn.execute(
                    """
                    SELECT * FROM credit_ledger
                    WHERE source = 'play_purchase' AND provider_transaction_id = ? AND status = 'granted'
                    """,
                    (req.purchaseToken,),
                ).fetchone()
                deduct = min(wallet["balance"], pkg.credits) if granted is not None else 0
                new_balance = wallet["balance"] - deduct
                tx_id = f"tx_{uuid.uuid4().hex}"
                conn.execute(
                    "UPDATE wallets SET balance = ?, updated_at = ? WHERE wallet_reference = ?",
                    (new_balance, now, req.walletReference),
                )
                conn.execute(
                    """
                    INSERT INTO credit_ledger (
                        transaction_id, wallet_reference, source, product_id,
                        credit_delta, provider_transaction_id, status,
                        created_at, idempotency_key, reservation_id
                    ) VALUES (?, ?, 'refund', ?, ?, ?, 'reversed', ?, ?, NULL)
                    """,
                    (
                        tx_id,
                        req.walletReference,
                        pkg.productId,
                        -deduct,
                        f"revoked:{req.purchaseToken}",
                        now,
                        rev_key,
                    ),
                )
                row = conn.execute("SELECT * FROM credit_ledger WHERE transaction_id = ?", (tx_id,)).fetchone()
                return PlayPurchaseValidateResponse(
                    status="reversed",
                    acknowledged=False,
                    balance=new_balance,
                    transaction=_row_to_ledger(row),
                    idempotentReplay=False,
                )

            # pending / cancelled / rejected
            state_key = f"play_state:{req.idempotencyKey}:{req.purchaseState}"
            existing_state = conn.execute(
                """
                SELECT * FROM credit_ledger
                WHERE wallet_reference = ? AND idempotency_key = ?
                """,
                (req.walletReference, state_key),
            ).fetchone()
            if existing_state is not None:
                return PlayPurchaseValidateResponse(
                    status=existing_state["status"],
                    acknowledged=False,
                    balance=wallet["balance"],
                    transaction=_row_to_ledger(existing_state),
                    idempotentReplay=True,
                )

            ledger_status = "pending" if req.purchaseState == "pending" else "rejected"
            tx_id = f"tx_{uuid.uuid4().hex}"
            conn.execute(
                """
                INSERT INTO credit_ledger (
                    transaction_id, wallet_reference, source, product_id,
                    credit_delta, provider_transaction_id, status,
                    created_at, idempotency_key, reservation_id
                ) VALUES (?, ?, 'play_purchase', ?, 0, NULL, ?, ?, ?, NULL)
                """,
                (tx_id, req.walletReference, pkg.productId, ledger_status, now, state_key),
            )
            row = conn.execute("SELECT * FROM credit_ledger WHERE transaction_id = ?", (tx_id,)).fetchone()
            return PlayPurchaseValidateResponse(
                status=ledger_status,
                acknowledged=False,
                balance=wallet["balance"],
                transaction=_row_to_ledger(row),
                idempotentReplay=False,
            )

    def claim_rewarded_ad(self, req: RewardedAdClaimRequest) -> CreditOperationResponse:
        if not self.catalog.rewardedAd.enabled or self.catalog.rewardedAd.creditsPerView <= 0:
            raise DomainError("REWARDED_AD_DISABLED", "Recompensa por anúncio desativada.", 503)

        if self.settings.admob_ssv_secret:
            payload = f"{req.walletReference}:{req.providerTransactionId}".encode("utf-8")
            if not verify_webhook_signature(payload, req.signature, self.settings.admob_ssv_secret):
                raise DomainError("INVALID_AD_SIGNATURE", "Assinatura de recompensa de anúncio inválida.", 401)
        elif self.settings.env == "production":
            raise DomainError(
                "AD_VERIFICATION_NOT_CONFIGURED",
                "Verificação server-side de anúncios não configurada em produção.",
                503,
            )

        now = _utc_now_iso()
        today_prefix = now[:10]
        grant = self.catalog.rewardedAd.creditsPerView
        with self.db.transaction() as conn:
            wallet = self._require_wallet(conn, req.walletReference)

            existing = conn.execute(
                """
                SELECT * FROM credit_ledger
                WHERE (source = 'rewarded_ad' AND provider_transaction_id = ?)
                   OR (wallet_reference = ? AND idempotency_key = ?)
                """,
                (req.providerTransactionId, req.walletReference, req.idempotencyKey),
            ).fetchone()
            if existing is not None:
                return CreditOperationResponse(
                    transaction=_row_to_ledger(existing),
                    balance=wallet["balance"],
                    idempotentReplay=True,
                )

            daily_count = conn.execute(
                """
                SELECT COUNT(*) AS cnt FROM credit_ledger
                WHERE wallet_reference = ?
                  AND source = 'rewarded_ad'
                  AND status = 'granted'
                  AND substr(created_at, 1, 10) = ?
                """,
                (req.walletReference, today_prefix),
            ).fetchone()["cnt"]
            if daily_count >= self.catalog.rewardedAd.dailyLimit:
                raise DomainError(
                    "REWARDED_AD_DAILY_LIMIT",
                    f"Limite diário de {self.catalog.rewardedAd.dailyLimit} anúncios recompensados atingido.",
                    429,
                )

            new_balance = wallet["balance"] + grant
            tx_id = f"tx_{uuid.uuid4().hex}"
            conn.execute(
                "UPDATE wallets SET balance = ?, updated_at = ? WHERE wallet_reference = ?",
                (new_balance, now, req.walletReference),
            )
            conn.execute(
                """
                INSERT INTO credit_ledger (
                    transaction_id, wallet_reference, source, product_id,
                    credit_delta, provider_transaction_id, status,
                    created_at, idempotency_key, reservation_id
                ) VALUES (?, ?, 'rewarded_ad', ?, ?, ?, 'granted', ?, ?, NULL)
                """,
                (
                    tx_id,
                    req.walletReference,
                    req.adNetwork,
                    grant,
                    req.providerTransactionId,
                    now,
                    req.idempotencyKey,
                ),
            )
            row = conn.execute("SELECT * FROM credit_ledger WHERE transaction_id = ?", (tx_id,)).fetchone()
            return CreditOperationResponse(
                transaction=_row_to_ledger(row),
                balance=new_balance,
                idempotentReplay=False,
            )

    def record_telemetry(self, event: TelemetryEventRequest) -> dict[str, str]:
        event_id = f"evt_{uuid.uuid4().hex}"
        now = _utc_now_iso()
        with self.db.transaction() as conn:
            conn.execute(
                """
                INSERT INTO operational_telemetry (
                    event_id, event_name, screen_name, platform,
                    app_version, metadata_json, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    event_id,
                    event.eventName,
                    event.screenName,
                    event.platform,
                    event.appVersion,
                    json.dumps(event.metadata, ensure_ascii=False),
                    now,
                ),
            )
        return {"eventId": event_id, "status": "recorded"}

