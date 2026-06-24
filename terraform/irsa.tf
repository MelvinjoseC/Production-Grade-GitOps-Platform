# ==========================================
# 1. IAM Role & Policy for EBS CSI Driver
# ==========================================

resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}


# ==========================================
# 2. S3 Bucket & IAM Role for Loki Log Storage
# ==========================================

# S3 Bucket for Loki blocks, indexes, and cache
resource "aws_s3_bucket" "loki_storage" {
  bucket        = "${var.cluster_name}-loki-storage-bucket"
  force_destroy = true # For demo project deletion; in production, keep to false

  tags = {
    Name = "${var.cluster_name}-loki-storage-bucket"
  }
}

# Block public access to Loki S3 bucket (security standard)
resource "aws_s3_bucket_public_access_block" "loki_storage" {
  bucket = aws_s3_bucket.loki_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Policy for Loki to read/write from/to the S3 bucket
resource "aws_iam_policy" "loki_s3" {
  name        = "${var.cluster_name}-loki-s3-policy"
  description = "IAM Policy for Loki to access S3 bucket for log storage"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.loki_storage.arn,
          "${aws_s3_bucket.loki_storage.arn}/*"
        ]
      }
    ]
  })
}

# IAM Role for Loki Service Account (IRSA)
resource "aws_iam_role" "loki_s3" {
  name = "${var.cluster_name}-loki-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Condition = {
        StringEquals = {
          # Restricting role assumption to the Loki service account in the monitoring namespace
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:monitoring:loki"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "loki_s3" {
  policy_arn = aws_iam_policy.loki_s3.arn
  role       = aws_iam_role.loki_s3.name
}
