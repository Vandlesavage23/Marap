# GitHub Actions OIDC: the deploy workflows assume this role with short-lived credentials. No IAM user
# or long-lived access key exists anywhere.

locals {
  github_oidc_url = "token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://${local.github_oidc_url}"
  client_id_list = ["sts.amazonaws.com"]
  # AWS validates GitHub's certificate chain itself; the thumbprint is required by the API but ignored.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://${local.github_oidc_url}"
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "${local.github_oidc_url}:sub"
      values   = [for p in var.github_oidc_subject_suffixes : "repo:${var.github_repository}:${p}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "${local.name_prefix}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_assume.json
  max_session_duration = 3600
}

locals {
  ecs_arn_prefix = "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}"
  deploy_service_arns = [
    for s in ["api", "ws", "worker", "beat"] : "${local.ecs_arn_prefix}:service/${aws_ecs_cluster.this.name}/${local.name_prefix}-${s}"
  ]
  deploy_family_arns = [
    for s in ["api", "ws", "worker", "beat", "migrate"] : "${local.ecs_arn_prefix}:task-definition/${local.name_prefix}-${s}:*"
  ]
  deploy_pass_role_arns = concat(
    [module.api.execution_role_arn, module.api.task_role_arn],
    [module.ws.execution_role_arn, module.ws.task_role_arn],
    [module.worker.execution_role_arn, module.worker.task_role_arn],
    [module.beat.execution_role_arn, module.beat.task_role_arn],
    [module.migrate.execution_role_arn, module.migrate.task_role_arn],
  )
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPushPull"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:CompleteLayerUpload",
      "ecr:DescribeImages", "ecr:GetDownloadUrlForLayer", "ecr:InitiateLayerUpload",
      "ecr:PutImage", "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.backend.arn]
  }
  statement {
    sid       = "EcsTaskDefinitions"
    actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition", "ecs:ListTaskDefinitions"]
    resources = ["*"] # these ecs actions do not support resource-level permissions
  }
  statement {
    sid       = "EcsServices"
    actions   = ["ecs:DescribeServices", "ecs:UpdateService"]
    resources = local.deploy_service_arns
  }
  statement {
    sid       = "EcsRunMigrate"
    actions   = ["ecs:RunTask"]
    resources = ["${local.ecs_arn_prefix}:task-definition/${local.name_prefix}-migrate:*"]
    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.this.arn]
    }
  }
  statement {
    sid       = "EcsTasks"
    actions   = ["ecs:DescribeTasks", "ecs:StopTask", "ecs:ListTasks"]
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.this.arn]
    }
  }
  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = local.deploy_pass_role_arns
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
  statement {
    sid       = "ReadMigrateLogs"
    actions   = ["logs:GetLogEvents", "logs:DescribeLogStreams"]
    resources = ["${module.migrate.log_group_arn}:*"]
  }
  statement {
    sid     = "PreMigrationSnapshot"
    actions = ["rds:CreateDBSnapshot", "rds:AddTagsToResource"]
    resources = [
      module.rds.arn,
      "arn:aws:rds:${var.region}:${data.aws_caller_identity.current.account_id}:snapshot:${local.name_prefix}-premigrate-*",
    ]
  }
  statement {
    sid       = "DescribeSnapshots"
    actions   = ["rds:DescribeDBSnapshots", "rds:DescribeDBInstances"]
    resources = ["*"]
  }
  statement {
    sid       = "TargetHealth"
    actions   = ["elasticloadbalancing:DescribeTargetHealth", "elasticloadbalancing:DescribeTargetGroups"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
