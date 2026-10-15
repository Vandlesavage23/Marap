"""Versioned text-safety rules (Bible §7.3, §9.2, §11.5; MC-079). No LLM processing of user text.

`screen()` returns a verdict: approve, reject (clear violation, with a stable reason code) or review
(borderline → human queue). Rules are versioned (`RULESET_VERSION`) and covered by a test corpus in
English, Luganda and Swahili. Shared by description screening (`screen`) and chat (`contact_reason`,
`scam_reason`). Bump `RULESET_VERSION` whenever a pattern changes.
"""

import re
import unicodedata
from dataclasses import dataclass

RULESET_VERSION = "2026-10-2"

APPROVE, REJECT, REVIEW = "approve", "reject", "review"


@dataclass(frozen=True)
class Verdict:
    outcome: str
    reason: str = ""


_NUMBER_WORDS = {
    "zero": "0", "oh": "0", "one": "1", "two": "2", "three": "3", "four": "4", "five": "5", "six": "6",
    "seven": "7", "eight": "8", "nine": "9",
    # Luganda
    "zeero": "0", "emu": "1", "bbiri": "2", "ssatu": "3", "nnya": "4", "ttaano": "5", "mukaaga": "6",
    "musanvu": "7", "munaana": "8", "mwenda": "9",
    # Swahili
    "sifuri": "0", "moja": "1", "mbili": "2", "tatu": "3", "nne": "4", "tano": "5", "sita": "6",
    "saba": "7", "nane": "8", "tisa": "9",
}  # fmt: skip
_WORD_RE = re.compile(r"\b(" + "|".join(sorted(_NUMBER_WORDS, key=len, reverse=True)) + r")\b")

_URL = re.compile(
    r"(https?://|www\.|\b[a-z0-9-]+\.(com|net|org|ug|co|io|me|info|biz|app|link|ly|tk)\b)", re.I
)
_EMAIL = re.compile(r"[\w.+-]+\s*(@|\(at\)|\[at\])\s*[\w-]+\s*(\.|\(dot\)|\[dot\])\s*\w+", re.I)
_EMAIL_PROVIDER = re.compile(r"\b(gmail|yahoo|hotmail|outlook|proton\s?mail|icloud)\b", re.I)
_MESSAGING = re.compile(
    r"\b(whats\s?app|watsap|wa\.me|telegram|signal|snap\s?chat|instagram|insta|facebook|fb|"
    r"tik\s?tok|imo|viber|wechat|messenger|dm\s+me|inbox\s+me)\b",
    re.I,
)
# Contact-me phrases: English, Luganda, Swahili.
_CONTACT_PHRASES = re.compile(
    r"\b(call me|text me|message me|reach me (on|at)|my (phone )?(number|contact)|contact me (on|at)|"
    r"nkubira|mpita ku|mpandikira|ntumire (ku|ennamba)|nnamba yange|ennamba yange|ndi ku|"
    r"nipigie|nipigie simu|nitumie ujumbe|namba yangu|nitafute (kwa|ku)|nipate (kwa|ku))\b",
    re.I,
)
_MONEY_REQUEST = re.compile(
    r"\b((send|give|lend|transfer|wire|tuma|nitumie|ntumire|ntumidde|mpa|nipe)\s+(me\s+)?"
    r"(some\s+)?(money|cash|funds|airtime|pesa|ssente|momo|data)|"
    r"mobile money|momo pay|airtel money|mtn money|western union|moneygram|bitcoin|crypto|forex|"
    r"invest(ment)? (with|in)|loan|school fees help|i need (money|help with (rent|fees))|"
    r"nsaba ssente|naomba pesa)\b",
    re.I,
)
_PROFANITY = re.compile(
    r"(\w*fuck\w*|\w*shit\w*|\w*bitch\w*|\bpussy|\bdick\b|\bcock\b|\bslut\b|\bwhore\b|\bmalaya\b|\bkuma\b|\bmboro\b|\bkunyaz\w*)",
    re.I,
)
_SEXUAL = re.compile(r"\b(hookup|one night|sugar (daddy|mummy|mommy)|sex partner|nudes?)\b", re.I)


def _digits_in(text: str) -> int:
    """Longest run of digits once separators and spelled-out digits are folded."""
    t = _WORD_RE.sub(lambda m: _NUMBER_WORDS[m.group(0)], text)
    t = re.sub(r"(?<=\d)[\s.\-_/()+,:;|*]+(?=\d)", "", t)
    t = re.sub(r"(?<=\d)[ol](?=\d)", "0", t, flags=re.I)  # 07o2 / 07l2 style obfuscation
    runs = [len(m) for m in re.findall(r"\d+", t)]
    return max(runs, default=0)


def _normalise(text: str) -> str:
    return unicodedata.normalize("NFKC", text).casefold()


def contact_reason(raw: str) -> str | None:
    """Why `raw` shares contact details (phone/email/link/messaging app/"call me" phrase), else None."""
    text = _normalise(raw)
    if _EMAIL.search(text) or _EMAIL_PROVIDER.search(text):
        return "email"
    if _URL.search(text):
        return "url"
    if _MESSAGING.search(text):
        return "messaging_app"
    if _digits_in(text) >= 7:
        return "phone_number"
    if _CONTACT_PHRASES.search(text):
        return "contact_details"
    return None


_SCAM = re.compile(
    r"\b(western union|moneygram|bitcoin|crypto|usdt|forex|gift ?cards?|itunes card|"
    r"(visa|customs|clearance|shipping|parcel|processing) (fee|fees|charges?)|"
    r"(hospital|medical|surgery) bills?|stranded|stuck (at|in) (the )?airport|"
    r"(send|give|lend|transfer|tuma|nitumie|ntumire|ntumidde|mpa|nipe)\s+(me\s+)?(some\s+)?"
    r"(money|cash|funds|airtime|pesa|ssente|momo|data)|"
    r"mobile money|momo|airtel money|mtn money|nsaba ssente|naomba pesa|"
    r"invest(ment)? (with|in)|double your money|i need (money|help with (rent|fees|bills)))\b",
    re.I,
)


def scam_reason(raw: str) -> str | None:
    """Heuristic scam/financial-request signal. Flags a message; it NEVER blocks silently (Bible §9.2)."""
    text = _normalise(raw)
    if _SCAM.search(text):
        return "financial_request"
    return None


def screen(raw: str) -> Verdict:
    """Description screening: reject clear violations, send borderline text to human review."""
    reason = contact_reason(raw)
    if reason:
        return Verdict(REJECT, reason)
    text = _normalise(raw)
    if _MONEY_REQUEST.search(text):
        return Verdict(REJECT, "money_request")
    if _SEXUAL.search(text):
        return Verdict(REJECT, "sexual_content")
    if _PROFANITY.search(text):
        return Verdict(REVIEW, "profanity")
    return Verdict(APPROVE)
