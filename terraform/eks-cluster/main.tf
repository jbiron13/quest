provider "aws" {
  region = var.region
}

locals {
  azs = [ "${var.region}a","${var.region}b"]
}

resource "aws_cloudwatch_log_group" "this" {
  count = length(var.cluster_enabled_log_types) > 0 && var.create_eks ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_in_days
  kms_key_id        = var.cluster_log_kms_key_id

  tags = var.tags
}
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name                 = var.cluster_name
  cidr                 = "10.0.0.0/16"
  azs                  = local.azs
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"              = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"     = "1"
  }
}

resource "aws_eks_cluster" "this" {
  count = var.create_eks ? 1 : 0

  name                      = var.cluster_name
  enabled_cluster_log_types = var.cluster_enabled_log_types
  role_arn                  = local.cluster_iam_role_arn
  version                   = var.cluster_version

  # enable_irsa = true

  vpc_config {
    security_group_ids      = compact([local.cluster_security_group_id])
    subnet_ids              = module.vpc.private_subnets
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  kubernetes_network_config {
    service_ipv4_cidr = var.cluster_service_ipv4_cidr
  }

  dynamic "encryption_config" {
    for_each = toset(var.cluster_encryption_config)

    content {
      provider {
        key_arn = encryption_config.value["provider_key_arn"]
      }
      resources = encryption_config.value["resources"]
    }
  }

  tags = merge(
    var.tags,
    var.cluster_tags,
  )

  timeouts {
    create = var.cluster_create_timeout
    delete = var.cluster_delete_timeout
    update = var.cluster_update_timeout
  }

  depends_on = [
    aws_security_group_rule.cluster_egress_internet,
    aws_security_group_rule.cluster_https_worker_ingress,
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceControllerPolicy,
    aws_cloudwatch_log_group.this
  ]
    
}

data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.this[0].name
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.this[0].name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "aws_security_group" "cluster" {
  count = var.cluster_create_security_group && var.create_eks ? 1 : 0

  name_prefix = var.cluster_name
  description = "EKS cluster security group."
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-eks_cluster_sg"
    },
  )
}

resource "aws_security_group_rule" "cluster_egress_internet" {
  count = var.cluster_create_security_group && var.create_eks ? 1 : 0

  description       = "Allow cluster egress access to the Internet."
  protocol          = "-1"
  security_group_id = local.cluster_security_group_id
  cidr_blocks       = var.cluster_egress_cidrs
  from_port         = 0
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "cluster_https_worker_ingress" {
  count = var.cluster_create_security_group && var.create_eks && var.worker_create_security_group ? 1 : 0

  description              = "Allow pods to communicate with the EKS cluster API."
  protocol                 = "tcp"
  # security_group_id        = local.cluster_security_group_id
  security_group_id        = aws_security_group.cluster[0].id
  # source_security_group_id = local.worker_security_group_id
  source_security_group_id = aws_security_group.workers[0].id
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster_private_access_cidrs_source" {
  for_each = var.create_eks && var.cluster_create_endpoint_private_access_sg_rule && var.cluster_endpoint_private_access && var.cluster_endpoint_private_access_cidrs != null ? toset(var.cluster_endpoint_private_access_cidrs) : []

  description = "Allow private K8S API ingress from custom CIDR source."
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = [each.value]

  security_group_id = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "cluster_private_access_sg_source" {
  count = var.create_eks && var.cluster_create_endpoint_private_access_sg_rule && var.cluster_endpoint_private_access && var.cluster_endpoint_private_access_sg != null ? length(var.cluster_endpoint_private_access_sg) : 0

  description              = "Allow private K8S API ingress from custom Security Groups source."
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = var.cluster_endpoint_private_access_sg[count.index]

  security_group_id = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id
}

resource "aws_iam_role" "cluster" {
  count = var.manage_cluster_iam_resources && var.create_eks ? 1 : 0

  name_prefix           = var.cluster_iam_role_name != "" ? null : var.cluster_name
  name                  = var.cluster_iam_role_name != "" ? var.cluster_iam_role_name : null
  assume_role_policy    = data.aws_iam_policy_document.cluster_assume_role_policy.json
  permissions_boundary  = var.permissions_boundary
  path                  = var.iam_path
  force_detach_policies = true

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  count = var.manage_cluster_iam_resources && var.create_eks ? 1 : 0

  policy_arn = "${local.policy_arn_prefix}/AmazonEKSClusterPolicy"
  role       = local.cluster_iam_role_name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  count = var.manage_cluster_iam_resources && var.create_eks ? 1 : 0

  policy_arn = "${local.policy_arn_prefix}/AmazonEKSServicePolicy"
  role       = local.cluster_iam_role_name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceControllerPolicy" {
  count = var.manage_cluster_iam_resources && var.create_eks ? 1 : 0

  policy_arn = "${local.policy_arn_prefix}/AmazonEKSVPCResourceController"
  role       = local.cluster_iam_role_name
}

/*
 Adding a policy to cluster IAM role that allow permissions
 required to create AWSServiceRoleForElasticLoadBalancing service-linked role by EKS during ELB provisioning
*/

data "aws_iam_policy_document" "cluster_elb_sl_role_creation" {
  count = var.manage_cluster_iam_resources && var.create_eks ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeAddresses"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cluster_elb_sl_role_creation" {
  count = var.manage_cluster_iam_resources && var.create_eks ? 1 : 0

  name_prefix = "${var.cluster_name}-elb-sl-role-creation"
  description = "Permissions for EKS to create AWSServiceRoleForElasticLoadBalancing service-linked role"
  policy      = data.aws_iam_policy_document.cluster_elb_sl_role_creation[0].json
  path        = var.iam_path

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_elb_sl_role_creation" {
  count = var.manage_cluster_iam_resources && var.create_eks ? 1 : 0

  policy_arn = aws_iam_policy.cluster_elb_sl_role_creation[0].arn
  role       = local.cluster_iam_role_name
}

/*
 Adding a policy to cluster IAM role that deny permissions to logs:CreateLogGroup
 it is not needed since we create the log group ourselve in this module, and it is causing trouble during cleanup/deletion
*/

data "aws_iam_policy_document" "cluster_deny_log_group" {
  count = var.manage_cluster_iam_resources && var.create_eks ? 1 : 0

  statement {
    effect = "Deny"
    actions = [
      "logs:CreateLogGroup"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cluster_deny_log_group" {
  count = var.manage_cluster_iam_resources && var.create_eks ? 1 : 0

  name_prefix = "${var.cluster_name}-deny-log-group"
  description = "Deny CreateLogGroup"
  policy      = data.aws_iam_policy_document.cluster_deny_log_group[0].json
  path        = var.iam_path

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_deny_log_group" {
  count = var.manage_cluster_iam_resources && var.create_eks ? 1 : 0

  policy_arn = aws_iam_policy.cluster_deny_log_group[0].arn
  role       = local.cluster_iam_role_name
}
