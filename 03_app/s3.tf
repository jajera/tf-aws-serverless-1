resource "aws_s3_bucket" "store" {
  bucket        = "store-${local.suffix}"
  force_destroy = true
}
