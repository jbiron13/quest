cluster_name = "quest4"
cluster_version = "1.20"
region = "us-east-1"

map_users = [
        {
            userarn = "arn:aws:iam::203733355362:user/samaritan",
            username = "samaritan",
            groups = [ "system:masters" ]
        },
        {
            userarn = "arn:aws:iam::203733355362:user/wompa",
            username = "wompa",
            groups = [ "system:masters" ]
        }
]


node_groups_defaults = {
ami_type  = "AL2_x86_64"
disk_size = 50
}

node_groups = {
    workers-0 = {
        desired_capacity = 1
        max_capacity     = 10
        min_capacity     = 1

        instance_types = ["t3.large"]
        capacity_type  = "ON_DEMAND"
        k8s_labels = {
        Example    = "managed_node_groups"
        GithubRepo = "terraform-aws-eks"
        GithubOrg  = "terraform-aws-modules"
        }
        update_config = {
            max_unavailable_percentage = 50 # or set `max_unavailable`
        }
    }
}

enable_irsa = true

