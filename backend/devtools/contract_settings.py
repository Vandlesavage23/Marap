"""Settings for the mobile contract tests (apps/mobile/tool/run_contract_tests.sh). local/test only.

The test settings (fake SMS / identity / Play / gateway providers, in-memory channel layer, eager
Celery, host `api.mc.test`) plus an optional S3 endpoint, so the media upload flow can talk to a
`moto_server` instead of AWS. Never import this in production."""

import os

from config.settings.test import *  # noqa: F403

AWS_S3_ENDPOINT_URL = os.environ.get("MC_CONTRACT_S3_ENDPOINT", "")
