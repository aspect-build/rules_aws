# Bazel rules for Amazon Web Services (AWS)

> [!IMPORTANT]
> This module was previously published as `aspect_rules_aws`. To upgrade, replace `aspect_rules_aws` with `rules_aws` in your `bazel_dep`, `load()` statements and flags.

> [!NOTE]
> This repository uses the [Aspect CLI](https://github.com/aspect-build/aspect-cli) for CI and local development.
> See the [docs](https://docs.aspect.build/cli/overview) and [install instructions](https://docs.aspect.build/cli/install) to get started.

Integrations for using AWS as a deployment target for Bazel-built artifacts.

## Installation

From the release you wish to use:
<https://github.com/aspect-build/rules_aws/releases>
copy the `bazel_dep` snippet into your `MODULE.bazel` file.

## Choosing an AWS CLI version

Select the CLI version in `MODULE.bazel`:

```starlark
aws = use_extension("@rules_aws//aws:extensions.bzl", "aws")
aws.toolchain(aws_cli_version = "2.39.6")
```

Versions mirrored in [versions.bzl](aws/private/versions.bzl) are verified automatically.
Any other release AWS publishes can be used by also pinning its hashes with `integrity_hashes`
(keyed by `darwin`, `linux-aarch64`, `linux-x86_64` and `windows`). If they're omitted, Bazel
prints the hashes to pin on first fetch.

## Windows

The MSI installer is unpacked with an administrative install (`msiexec /a`), which needs no admin
rights and installs nothing on the machine. `bazel run @aws` starts the CLI through a batch file, so
`cmd.exe` interprets `&`, `|`, `<`, `>` and `^` in arguments that contain no space. The CLI finds its
home directory through `USERPROFILE`, which Bazel doesn't pass to actions, so actions running
`$(AWS_CLI_BIN)` need `--action_env=USERPROFILE`.

## Support

This ruleset is community-supported with help from [Aspect](https://aspect.build).
We review pull requests and fix critical issues when we can, but we cannot promise timelines.
Contributions are welcome.
