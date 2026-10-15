import pytest

from mc.safety import selectors, text_rules

CONTACT = [
    "call me on 0772123456", "my whatsapp is on", "add me on insta", "email me at jo@gmail.com",
    "see https://x.co/a", "namba yangu ni 0712 345 678", "nkubira ku ssimu yange", "zero seven seven two one two three four five six",
    "text me later", "nitumie ujumbe", "mpandikira nga", "tuwandike ku telegram",
]  # fmt: skip
NOT_CONTACT = [
    "Good morning! How was your day?", "I finish work at 5 and then go to church",
    "I was born in 1995", "I have 2 sisters and 3 brothers", "Nsiimye okukumanya", "Habari za asubuhi, siku yako ilikuwaje?",
    "Let's talk about our families", "Sunday lunch at 1 pm at my mother's house sounds lovely",
]  # fmt: skip
SCAM = [
    "please send me money for the hospital bill", "I am stranded at the airport", "pay the customs fee and I come",
    "invest with me in bitcoin", "tuma pesa kidogo", "ntumire ssente nsobole okutuuka", "naomba pesa ya kodi",
    "momo number is 0772", "buy me a gift card", "western union works for me",
]  # fmt: skip
NOT_SCAM = [
    "I work in a bank", "My business sells matooke and I enjoy it", "Money isn't everything, family matters most",
    "Habari yako? Ninafurahi kukutana nawe", "Ssente si kintu kikulu nnyo", "Let's meet at the mall café",
]  # fmt: skip


@pytest.mark.parametrize("text", CONTACT)
def test_contact_details_detected(text):
    assert text_rules.contact_reason(text) is not None
    assert selectors.contact_details_reason(text) is not None


@pytest.mark.parametrize("text", NOT_CONTACT)
def test_normal_chat_is_not_contact(text):
    assert text_rules.contact_reason(text) is None


@pytest.mark.parametrize("text", SCAM)
def test_scam_heuristics_flag(text):
    assert text_rules.scam_reason(text) == "financial_request"
    assert selectors.scam_flag(text)


@pytest.mark.parametrize("text", NOT_SCAM)
def test_innocent_money_talk_is_not_flagged(text):
    assert text_rules.scam_reason(text) is None


def test_ruleset_is_versioned_and_description_screen_still_works():
    assert text_rules.RULESET_VERSION.startswith("2026-")
    assert text_rules.screen("call me on 0772123456").reason == "phone_number"
    assert text_rules.screen("a lovely, honest person").outcome == "approve"
