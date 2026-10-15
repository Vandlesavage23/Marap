"""Vendor reason → normalised `reason_code` (Bible §11.1). Unknown codes map to `unknown`
(never raised) so a vendor adding a code cannot break the pipeline."""

FACE_MISMATCH = "face_mismatch"
DOC_UNREADABLE = "doc_unreadable"
DOC_EXPIRED = "doc_expired"
LIVENESS_FAILED = "liveness_failed"
UNDERAGE = "underage"
DUPLICATE_IDENTITY = "duplicate_identity"
BANNED = "banned"
DOB_MISSING = "dob_missing"
ID_NUMBER_MISSING = "id_number_missing"
VENDOR_ERROR = "vendor_error"
UNKNOWN = "unknown"

# Smile ID result codes (to be confirmed against the sandbox in MC-002/MC-030).
SMILE_ID_REASONS: dict[str, str] = {
    "1012": FACE_MISMATCH,
    "1013": FACE_MISMATCH,
    "0811": DOC_UNREADABLE,
    "0812": DOC_UNREADABLE,
    "0813": DOC_UNREADABLE,
    "0814": DOC_EXPIRED,
    "2204": LIVENESS_FAILED,
    "2205": LIVENESS_FAILED,
    "2206": LIVENESS_FAILED,
}

# Reasons after which an in-app appeal is never offered (support only).
NO_APPEAL = frozenset({UNDERAGE, DUPLICATE_IDENTITY, BANNED})


def map_smile_id(code: str) -> str:
    return SMILE_ID_REASONS.get(str(code), UNKNOWN)
