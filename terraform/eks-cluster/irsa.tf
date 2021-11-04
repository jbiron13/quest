# Enable IAM Roles for EKS Service-Accounts (IRSA).

# The Root CA Thumbprint for an OpenID Connect Identity Provider is currently
# Being passed as a default value which is the same for all regions and
# Is valid until (Jun 28 17:39:16 2034 GMT).
# https://crt.sh/?q=9E99A48A9960B14926BB7F3B02E22DA2B0AB7280
# https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc_verify-thumbprint.html
# https://github.com/terraform-providers/terraform-provider-aws/issues/10104

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  count = var.enable_irsa && var.create_eks ? 1 : 0

  client_id_list  = local.client_id_list
  thumbprint_list = [var.eks_oidc_root_ca_thumbprint]
  url             = local.cluster_oidc_issuer_url

  tags = merge(
    {
      Name = "${var.cluster_name}-eks-irsa"
    },
    var.tags
  )
}

locals {
  k8s_service_account_namespace = "kube-system"
  k8s_service_account_name      = "cluster-autoscaler-aws"
  external_secrets_account_name = "external-secrets"

  load_balancer_account_name = "aws-load-balancer-controller"
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "aws_iam_policy" "lbc" {
  name = "AWSLoadBalancerControllerIAMPolicy-${aws_eks_cluster.this[0].name}"
  policy = file("AWSLoadBalancerControllerIAMPolicy.json")
} 

module "load_balancer_role" {

  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 4.3"

  create_role = true

  role_name = "AmazonEKSLoadBalancerControllerRole-${aws_eks_cluster.this[0].name}"

  tags = {
    Role = "AmazonEKSLoadBalancerControllerRole"
  }

  provider_url = replace(local.cluster_oidc_issuer_url, "https://", "")

  role_policy_arns = [ aws_iam_policy.lbc.arn ]
  number_of_role_policy_arns = 1
}

resource "helm_release" "load_balancer_controller" {

  name             = "aws-load-balancer-controller"
  namespace        = "kube-system"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  create_namespace = false

  set {
    name  = "awsRegion"
    value = var.region
  }
  set {
    name = "clusterName"
    value = aws_eks_cluster.this[0].name
  }
  set {
    name = "serviceAccount.create"
    value = "true"
  }
  set {
    name = "serviceAccount.name"
    value = local.load_balancer_account_name
  }
  set {
    name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = "${module.load_balancer_role.iam_role_arn}"
  }
}