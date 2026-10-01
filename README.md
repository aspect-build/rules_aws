# Bazel rules for Amazon Web Services (AWS)

> [!NOTE]
> This repository uses the [Aspect CLI](https://github.com/aspect-build/aspect-cli) for CI and local development.
> See the [docs](https://docs.aspect.build/cli/overview) and [install instructions](https://docs.aspect.build/cli/install) to get started.

Integrations for using AWS as a deployment target for Bazel-built artifacts.

This repo is EXPERIMENTAL! We have not yet decided whether to take any long-term commitment to support or maintenance of code here. We may archive and abandon the repo at any time, and may make undocumented breaking changes between releases.

## Installation

From the release you wish to use:
<https://github.com/aspect-build/rules_aws/releases>
copy the WORKSPACE snippet into your `WORKSPACE` file.

To use a commit rather than a release, you can point at any SHA of the repo.

For example to use commit `abc123`:

1. Replace `url = "https://github.com/aspect-build/rules_aws/releases/download/v0.1.0/rules_aws-v0.1.0.tar.gz"` with a GitHub-provided source archive like `url = "https://github.com/aspect-build/rules_aws/archive/abc123.tar.gz"`
1. Replace `strip_prefix = "rules_aws-0.1.0"` with `strip_prefix = "rules_aws-abc123"`
1. Update the `sha256`. The easiest way to do this is to comment out the line, then Bazel will
   print a message with the correct value. Note that GitHub source archives don't have a strong
   guarantee on the sha256 stability, see
   <https://github.blog/2023-02-21-update-on-the-future-stability-of-source-code-archives-and-hashes/>

## Choosing an AWS CLI version

Select the CLI version in `MODULE.bazel`:

```starlark
aws = use_extension("@aspect_rules_aws//aws:extensions.bzl", "aws")
aws.toolchain(aws_cli_version = "2.36.19")
```

Versions mirrored in [versions.bzl](aws/private/versions.bzl) are verified automatically.
Any other release AWS publishes can be used by also pinning its hashes with `integrity_hashes`
(keyed by `darwin`, `linux-aarch64` and `linux-x86_64`). If they're omitted, Bazel prints the
hashes to pin on first fetch.

## Roadmap

Aspect plans to open-source our internal AWS support from our private monorepo.
These features are documented in the issue tracker.

# Telemetry & privacy policy

This ruleset collects limited usage data via [`tools_telemetry`](https://github.com/aspect-build/tools_telemetry), which is reported to Aspect Build Inc and governed by our [privacy policy](https://www.aspect.build/privacy-policy).
