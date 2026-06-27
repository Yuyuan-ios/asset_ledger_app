from __future__ import annotations

import sqlite3
from typing import Any, Optional

from db_entitlement_guard import DbEntitlementGuard, PROTECTED_TABLES
from import_firewall import allow_storage_import, install_import_firewall
from runtime_write_firewall import RblViolation, RuntimeWriteContext, RuntimeWriteFirewall
from verifier import EntitlementRecord

install_import_firewall()

with allow_storage_import():
    import storage as _storage


EntitlementClaimConflict = _storage.EntitlementClaimConflict
PurchaseTransactionReplay = _storage.PurchaseTransactionReplay
SubscriptionStateRecord = _storage.SubscriptionStateRecord
EntitlementBindingPolicy = _storage.EntitlementBindingPolicy
ENTITLEMENT_BINDING_POLICIES = _storage.ENTITLEMENT_BINDING_POLICIES


class EntitlementDBGateway:
    """The only supported runtime access path for subscription persistence."""

    def __init__(self, db_path: str):
        self._store = _storage.EntitlementStore(db_path, db_gateway=self)

    @property
    def db_path(self) -> str:
        return self._store.db_path

    def execute_write(
        self,
        conn: sqlite3.Connection,
        sql: str,
        parameters: tuple[Any, ...] = (),
        *,
        table_name: str,
        operation: str,
        context: Optional[RuntimeWriteContext] = None,
    ) -> sqlite3.Cursor:
        if table_name in PROTECTED_TABLES:
            active_context = context or RuntimeWriteFirewall.current_context()
            if active_context is not None:
                active_context = active_context.for_table(table_name)
            try:
                RuntimeWriteFirewall.enforce(active_context)
            except RblViolation:
                DbEntitlementGuard.log_block(
                    conn,
                    active_context,
                    table_name=table_name,
                    operation=operation,
                    reason=f"rbl_blocked_execute_write_{table_name}",
                )
                raise
            if active_context is None:
                raise RblViolation("RBL VIOLATION: unauthorized entitlement write attempt")
            with DbEntitlementGuard.scoped_write(
                conn,
                active_context,
                table_name=table_name,
                operation=operation,
            ):
                return conn.execute(sql, parameters)
        return conn.execute(sql, parameters)

    def internal_admin_write_context(
        self,
        *,
        operation: str,
        user_id: Optional[str] = None,
        product_id: Optional[str] = None,
        transaction_id: Optional[str] = None,
    ) -> RuntimeWriteContext:
        return RuntimeWriteContext.internal_admin_job(
            operation=operation,
            user_id=user_id,
            product_id=product_id,
            transaction_id=transaction_id,
        )

    def upsert_entitlement(
        self,
        record: EntitlementRecord,
        user_id: Optional[str] = None,
        write_context: Optional[RuntimeWriteContext] = None,
    ) -> EntitlementRecord:
        return self._store.upsert_entitlement(
            record,
            user_id=user_id,
            write_context=write_context,
        )

    def get_entitlement(self, app_account_token: str) -> Optional[EntitlementRecord]:
        return self._store.get_entitlement(app_account_token)

    def get_latest_entitlement_for_user(self, user_id: str) -> Optional[EntitlementRecord]:
        return self._store.get_latest_entitlement_for_user(user_id)

    def get_latest_max_entitlement_for_user(self, user_id: str) -> Optional[EntitlementRecord]:
        return self._store.get_latest_max_entitlement_for_user(user_id)

    def record_purchase_transaction(
        self,
        *,
        transaction_id: str,
        channel: str,
        user_id: str,
        product_id: str,
        payload_hash: str,
        entitlement_tier: str,
    ) -> bool:
        return self._store.record_purchase_transaction(
            transaction_id=transaction_id,
            channel=channel,
            user_id=user_id,
            product_id=product_id,
            payload_hash=payload_hash,
            entitlement_tier=entitlement_tier,
        )

    def get_subscription_state(
        self,
        user_id: str,
        product_id: str,
    ) -> Optional[Any]:
        return self._store.get_subscription_state(user_id, product_id)

    def upsert_subscription_state(
        self,
        *,
        user_id: str,
        product_id: str,
        state: str,
        authority_score: int,
        event_time: Optional[str],
        event_version: int,
        channel: str,
        transaction_id: str,
        write_context: Optional[RuntimeWriteContext] = None,
    ) -> Any:
        return self._store.upsert_subscription_state(
            user_id=user_id,
            product_id=product_id,
            state=state,
            authority_score=authority_score,
            event_time=event_time,
            event_version=event_version,
            channel=channel,
            transaction_id=transaction_id,
            write_context=write_context,
        )

    def next_subscription_event_version(self, user_id: str) -> int:
        return self._store.next_subscription_event_version(user_id)

    def append_subscription_audit_log(
        self,
        *,
        log_type: str,
        user_id: str,
        product_id: str,
        channel: str,
        authority_score: int,
        previous_state: Optional[str],
        new_state: Optional[str],
        event_time: Optional[str],
        transaction_id: str,
        reason: str,
        raw_payload_json: str,
    ) -> int:
        return self._store.append_subscription_audit_log(
            log_type=log_type,
            user_id=user_id,
            product_id=product_id,
            channel=channel,
            authority_score=authority_score,
            previous_state=previous_state,
            new_state=new_state,
            event_time=event_time,
            transaction_id=transaction_id,
            reason=reason,
            raw_payload_json=raw_payload_json,
        )

    def list_subscription_audit_log(
        self,
        log_type: Optional[str] = None,
    ) -> list[dict[str, Any]]:
        return self._store.list_subscription_audit_log(log_type)

    def list_active_entitlements(self) -> list[EntitlementRecord]:
        return self._store.list_active_entitlements()


EntitlementStore = EntitlementDBGateway
