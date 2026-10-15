"""Description screening now lives in the safety module's versioned rule set (MC-079); re-exported here
so profile code and tests keep a stable import path."""

from mc.safety.text_rules import APPROVE, REJECT, REVIEW, RULESET_VERSION, Verdict, screen

__all__ = ["APPROVE", "REJECT", "REVIEW", "RULESET_VERSION", "Verdict", "screen"]
