from django.db import models

from mc.common.models import BaseModel


class Block(BaseModel):
    """`blocker` has blocked `blocked` (Bible §7.10). Blocks are absolute and two-way in effect."""

    blocker = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="blocks_made"
    )
    blocked = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="blocks_received"
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["blocker", "blocked"], name="uniq_block"),
            models.CheckConstraint(
                condition=~models.Q(blocker=models.F("blocked")), name="block_not_self"
            ),
        ]
        indexes = [models.Index(fields=["blocked"])]
