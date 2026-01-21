# 1. Artifact Bucket
resource "aws_s3_bucket" "codepipeline_bucket_saikat" {
  bucket        = "${var.project_name}-artifacts-${random_id.suffix.hex}-saikat"
  force_destroy = true
}

resource "random_id" "suffix" {
  byte_length = 3
}

# 2. GitHub Connection (Version 2)
# NOTE: After 'terraform apply', you must go to AWS Console 
# Settings > Connections to "Update pending connection".
resource "aws_codestarconnections_connection" "github_saikat" {
  name          = "github-connection-saikat"
  provider_type = "GitHub"
}

# 3. IAM Role for both Build and Pipeline
resource "aws_iam_role" "pipeline_role_saikat" {
  name = "${var.project_name}-pipeline-role-saikat"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [ {
      Effect    = "Allow"
      Principal = {
        Service = ["codebuild.amazonaws.com", "codepipeline.amazonaws.com"]
      }
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "pipeline_admin_saikat" {
  role       = aws_iam_role.pipeline_role_saikat.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 4. CodeBuild Project
resource "aws_codebuild_project" "terraform_build_saikat" {
  name         = "${var.project_name}-build-saikat"
  service_role = aws_iam_role.pipeline_role_saikat.arn

  artifacts {
    type = "CODEPIPELINE" # Required when using CodePipeline
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "CODEPIPELINE" # Required when using CodePipeline
    buildspec = "buildspec.yml"
  }
}

# 5. CodePipeline
resource "aws_codepipeline" "terraform_pipeline_saikat" {
  name          = "${var.project_name}-pipeline-saikat"
  role_arn      = aws_iam_role.pipeline_role_saikat.arn
  pipeline_type = "V2" # Modern pipeline type

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.codepipeline_bucket_saikat.bucket
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection" # Updated to V2
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github_saikat.arn
        FullRepositoryId = "unuste37/terraform-cicd-25dec" # owner/repo format
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name            = "Terraform"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform_build_saikat.name
      }
    }
  }
}
