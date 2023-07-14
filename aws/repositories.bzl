"""Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies
"""

load("@aspect_bazel_lib//lib:repo_utils.bzl", "repo_utils")
load("@bazel_tools//tools/build_defs/repo:http.bzl", _http_archive = "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//aws/private:toolchains_repo.bzl", "PLATFORMS", "toolchains_repo")
load("//aws/private:versions.bzl", "TOOL_VERSIONS")

def http_archive(name, **kwargs):
    maybe(_http_archive, name = name, **kwargs)

# WARNING: any changes in this function may be BREAKING CHANGES for users
# because we'll fetch a dependency which may be different from one that
# they were previously fetching later in their WORKSPACE setup, and now
# ours took precedence. Such breakages are challenging for users, so any
# changes in this function should be marked as BREAKING in the commit message
# and released only in semver majors.
# This is all fixed by bzlmod, so we just tolerate it for now.
def rules_aws_dependencies():
    # The minimal version of bazel_skylib we require
    http_archive(
        name = "bazel_skylib",
        sha256 = "74d544d96f4a5bb630d465ca8bbcfe231e3594e5aae57e1edbf17a6eb3ca2506",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
        ],
    )
    http_archive(
        name = "aspect_bazel_lib",
        sha256 = "e3151d87910f69cf1fc88755392d7c878034a69d6499b287bcfc00b1cf9bb415",
        strip_prefix = "bazel-lib-1.32.1",
        url = "https://github.com/aspect-build/bazel-lib/releases/download/v1.32.1/bazel-lib-v1.32.1.tar.gz",
    )

########
# Remaining content of the file is only used to support toolchains.
########
_DOC = "Fetch external tools needed for aws toolchain"
_ATTRS = {
    "aws_cli_version": attr.string(mandatory = True, values = TOOL_VERSIONS.keys()),
    "download_host": attr.string(default = "https://awscli.amazonaws.com"),
    "platform": attr.string(mandatory = True, values = PLATFORMS.keys()),
}
_CLI_INSTALL_PATH = "installed"

def _release_info(rctx):
    release_info = TOOL_VERSIONS[rctx.attr.aws_cli_version][rctx.attr.platform]
    return {
        "url": "/".join([
            rctx.attr.download_host,
            release_info[0].format(rctx.attr.aws_cli_version),
        ]),
        "integrity": release_info[1],
    }

def _cli_install_error(result):
    fail("aws CLI unpacking failed.\nSTDOUT: {}\nSTDERR: {}".format(result.stdout, result.stderr))

def _install_linux(rctx, release_info):
    rctx.download_and_extract(
        url = release_info["url"],
        integrity = release_info["integrity"],
        stripPrefix = "aws",
    )
    result = rctx.execute(["./install", "--install-dir", _CLI_INSTALL_PATH])
    if result.return_code:
        _cli_install_error(result)

    # When we run the install program on Macos (for a Linux exec/target platform),
    # it will fail to run the aws command to determine its own version, and lay out
    # using a different path.

    if repo_utils.is_darwin(rctx):
        dist_dir = "v2/dist"
    else:
        dist_dir = "v2/{}/dist".format(rctx.attr.aws_cli_version)

    return (dist_dir, rctx.path("installed/{}/aws".format(dist_dir)))

def _install_darwin(rctx, release_info):
    rctx.download(url = release_info["url"], integrity = release_info["integrity"], output = "AWSCLI.pkg")
    result = rctx.execute(["pkgutil", "--expand-full", "AWSCLI.pkg", "installed"])
    if result.return_code:
        _cli_install_error(result)

        fail("aws CLI unpacking failed.\nSTDOUT: {}\nSTDERR: {}".format(result.stdout, result.stderr))
    dist_dir = "aws-cli.pkg/Payload/aws-cli"
    return (dist_dir, rctx.path("installed/{}/aws".format(dist_dir)))

# TODO: if we ever want to support Windows natively, this can be a starting point.
#def _install_windows(rctx, release_info):
#    rctx.download(url = release_info["url"], integrity = release_info["integrity"], output = "AWSCLI.msi")
#    # msiexec /a File.msi TARGETDIR=C:\MyInstallPoint /qn
#    result = rctx.execute(["msiexec", "/a", "AWSCLI.msi", "TARGETDIR={}".format(_CLI_INSTALL_PATH), "/qn"])
#    if result.return_code:
#        _cli_install_error(result)
#    return rctx.path("{}/".format(_CLI_INSTALL_PATH))

def _aws_repo_impl(rctx):
    if rctx.attr.platform.startswith("linux"):
        (version_dir, target_tool_path) = _install_linux(rctx, _release_info(rctx))
    elif rctx.attr.platform == "darwin":
        (version_dir, target_tool_path) = _install_darwin(rctx, _release_info(rctx))
    elif rctx.attr.platform == "windows":
        fail("Windows platform is unsupported: https://github.com/aspect-build/rules_aws/issues/14")
    else:
        fail("Unexpected fall-through choosing install method, please file a bug.")

    build_content = """\
# Generated by aws/repositories.bzl
load("@aspect_rules_aws//aws:toolchain.bzl", "aws_toolchain")
aws_toolchain(name = "aws_toolchain", target_tool_path = "{}")
""".format(target_tool_path)

    # Base BUILD file for this repository
    rctx.file("BUILD.bazel", build_content)

    rctx.file("installed/BUILD.bazel", """\
# Generated by aws/repositories.bzl
load("@rules_pkg//pkg:mappings.bzl", "pkg_attributes", "pkg_files")
package(default_visibility=["//visibility:public"])

_BINS = ["{v}/aws*"]

pkg_files(
    name = "bin_files",
    strip_prefix = "{v}",
    srcs = glob(_BINS),
    attributes = pkg_attributes(
        mode = "0755",
    ),
)

pkg_files(
    name = "files",
    strip_prefix = "{v}",
    srcs = glob(
        ["{v}/**"],
        exclude = _BINS,
    )
)
""".format(v = version_dir))

aws_repositories = repository_rule(
    _aws_repo_impl,
    doc = _DOC,
    attrs = _ATTRS,
)

# Wrapper macro around everything above, this is the primary API
def aws_register_toolchains(name, register = True, **kwargs):
    """Convenience macro for users which does typical setup.

    - create a repository for each built-in platform like "aws_linux_amd64" -
      this repository is lazily fetched when node is needed for that platform.
    - TODO: create a convenience repository for the host platform like "aws_host"
    - create a repository exposing toolchains for each platform like "aws_platforms"
    - register a toolchain pointing at each platform
    Users can avoid this macro and do these steps themselves, if they want more control.
    Args:
        name: base name for all created repos, like "aws1_14"
        register: whether to call through to native.register_toolchains.
            Should be True for WORKSPACE users, but false when used under bzlmod extension
        **kwargs: passed to each node_repositories call
    """
    for platform in PLATFORMS.keys():
        aws_repositories(
            name = name + "_" + platform,
            platform = platform,
            **kwargs
        )
        if register:
            native.register_toolchains("@%s_toolchains//:%s_toolchain" % (name, platform))

    toolchains_repo(
        name = name + "_toolchains",
        user_repository_name = name,
    )
