"Dependencies to fetch from remote docker registries"

load("@rules_oci//oci:pull.bzl", "oci_pull")

# As of 30 August 2023
PY_LAMBDA_LATEST = "sha256:489d4abc8644060e2e16db2ffaaafa157359761feaf9438bf26ed88e37e43d9c"

# See https://docs.aws.amazon.com/lambda/latest/dg/python-image.html#python-image-base
def aws_py_lambda_repositories(digest = PY_LAMBDA_LATEST):
    oci_pull(
        name = "aws_lambda_python",
        # tag = "3.11",
        digest = digest,
        platforms = ["linux/arm64/v8", "linux/amd64"],
        image = "public.ecr.aws/lambda/python",
    )

def _aws_py_lambda_impl(_):
    aws_py_lambda_repositories()

aws_py_lambda = module_extension(
    implementation = _aws_py_lambda_impl,
    # TODO: allow bzlmod users to control the digest
    # tag_classes = {"digest": digest},
)
