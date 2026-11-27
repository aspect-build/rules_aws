"""Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://bazel.build/rules/deploying#dependencies
"""

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
        sha256 = "9f38886a40548c6e96c106b752f242130ee11aaa068a56ba7e56f4511f33e4f2",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.6.1/bazel-skylib-1.6.1.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.6.1/bazel-skylib-1.6.1.tar.gz",
        ],
    )

########
# Remaining content of the file is only used to support toolchains.
########
_DOC = "Fetch external tools needed for aws toolchain"
_ATTRS = {
    "aws_cli_version": attr.string(mandatory = True),
    "download_host": attr.string(default = "https://awscli.amazonaws.com"),
    "integrity_hashes": attr.string_dict(doc = "Mapping from platform to the SRI integrity hash of its AWS CLI download."),
    "platform": attr.string(mandatory = True, values = PLATFORMS.keys()),
}
_CLI_INSTALL_PATH = "installed"

# Filenames AWS publishes each release under, used for versions not mirrored in TOOL_VERSIONS.
_FILENAMES = {
    "darwin": "AWSCLIV2-{}.pkg",
    "linux-aarch64": "awscli-exe-linux-aarch64-{}.zip",
    "linux-x86_64": "awscli-exe-linux-x86_64-{}.zip",
    "windows": "AWSCLIV2-{}.msi",
}

# TOOL_VERSIONS mirrors the Windows installer under "win32", see .aspect/mirror_releases.axl.
_MIRROR_PLATFORMS = {"windows": "win32"}

def _release_info(rctx):
    """Resolves the download url and integrity for the requested version and platform.

    The user-supplied integrity_hashes take precedence over the mirrored TOOL_VERSIONS.
    An empty integrity means the version isn't known; it's downloaded unverified and
    _warn_unpinned reports the hash to pin.
    """
    version = rctx.attr.aws_cli_version
    platform = rctx.attr.platform
    filename, integrity = TOOL_VERSIONS.get(version, {}).get(_MIRROR_PLATFORMS.get(platform, platform), (_FILENAMES[platform], ""))
    integrity = rctx.attr.integrity_hashes.get(platform, integrity)
    return {
        "url": "/".join([rctx.attr.download_host, filename.format(version)]),
        "integrity": integrity,
    }

def _warn_unpinned(rctx, release_info, result):
    if release_info["integrity"]:
        return

    # buildifier: disable=print
    print("""\
WARNING: aws CLI {version} is not mirrored in rules_aws, so {url} was downloaded without an integrity check.
To make this reproducible, pin it in the toolchain tag:
    aws.toolchain(
        aws_cli_version = "{version}",
        integrity_hashes = {{
            "{platform}": "{integrity}",
            ...
        }},
    )
""".format(
        version = rctx.attr.aws_cli_version,
        url = release_info["url"],
        platform = rctx.attr.platform,
        integrity = result.integrity,
    ))

def _cli_install_error(result):
    fail("aws CLI unpacking failed.\nSTDOUT: {}\nSTDERR: {}".format(result.stdout, result.stderr))

def _install_linux(rctx, release_info):
    dist_dir = "v2/{}/dist".format(rctx.attr.aws_cli_version)

    # The installer runs dist/aws to detect the version, which fails when the
    # downloaded CLI targets a different architecture from the repository host.
    # The dist directory is self-contained; extract it directly into the layer.
    result = rctx.download_and_extract(
        url = release_info["url"],
        integrity = release_info["integrity"],
        output = "{}/{}".format(_CLI_INSTALL_PATH, dist_dir),
        stripPrefix = "aws/dist",
    )
    _warn_unpinned(rctx, release_info, result)
    return (dist_dir, rctx.path("installed/{}/aws".format(dist_dir)))

def _install_darwin(rctx, release_info):
    result = rctx.download(url = release_info["url"], integrity = release_info["integrity"], output = "AWSCLI.pkg")
    _warn_unpinned(rctx, release_info, result)

    # NB: don't expect pkgutil on the PATH, users may run with --repo_env and /usr/sbin no longer appears
    result = rctx.execute(["/usr/sbin/pkgutil", "--expand-full", "AWSCLI.pkg", "installed"])
    if result.return_code:
        _cli_install_error(result)
    dist_dir = "aws-cli.pkg/Payload/aws-cli"
    return (dist_dir, rctx.path("installed/{}/aws".format(dist_dir)))

def _windows_path(rctx, path):
    return str(rctx.path(path)).replace("/", "\\")

def _install_windows(rctx, release_info):
    result = rctx.download(url = release_info["url"], integrity = release_info["integrity"], output = "AWSCLI.msi")
    _warn_unpinned(rctx, release_info, result)

    # An administrative install only unpacks the MSI: it needs no admin rights and installs nothing
    # on the machine. msiexec needs an absolute TARGETDIR and rejects the quotes rctx.execute puts
    # around arguments with spaces, so a batch file builds the command line from its own location.
    # Like pkgutil above, msiexec isn't expected on the PATH.
    rctx.file("extract.bat", "\r\n".join([
        "@echo off",
        "\"%SystemRoot%\\System32\\msiexec.exe\" /a \"%~dp0AWSCLI.msi\" /qn /Lwem \"%~dp0msiexec.log\" TARGETDIR=\"%~dp0{}\"".format(_CLI_INSTALL_PATH),
        "exit /b %ERRORLEVEL%",
        "",
    ]))

    # Explicitly relative, as NoDefaultCurrentDirectoryInExePath stops cmd from searching the cwd.
    result = rctx.execute(["cmd.exe", "/d", "/c", ".\\extract.bat"])
    if result.return_code:
        fail("aws CLI unpacking with msiexec failed with exit code {} (1618: another installation is in progress), see {}".format(result.return_code, _windows_path(rctx, "msiexec.log")))

    # The administrative install also leaves a copy of the MSI without its files in TARGETDIR.
    for leftover in ["AWSCLI.msi", "{}/AWSCLI.msi".format(_CLI_INSTALL_PATH), "extract.bat", "msiexec.log"]:
        rctx.delete(leftover)
    dist_dir = "Amazon/AWSCLIV2"
    return (dist_dir, rctx.path("{}/{}/aws.exe".format(_CLI_INSTALL_PATH, dist_dir)))

def _aws_repo_impl(rctx):
    if rctx.attr.platform.startswith("linux"):
        (version_dir, target_tool_path) = _install_linux(rctx, _release_info(rctx))
    elif rctx.attr.platform == "darwin":
        (version_dir, target_tool_path) = _install_darwin(rctx, _release_info(rctx))
    elif rctx.attr.platform == "windows":
        (version_dir, target_tool_path) = _install_windows(rctx, _release_info(rctx))
    else:
        fail("Unexpected fall-through choosing install method, please file a bug.")

    if rctx.attr.platform == "windows":
        # A copy of aws.exe can't find the Python runtime next to the original, and native_binary
        # copies on Windows, so `bazel run` starts the unpacked CLI through a batch file instead.
        rctx.file("aws.bat", "@\"{}\" %*\r\n".format(_windows_path(rctx, target_tool_path)))
        aws_target = ":aws.bat"
    else:
        aws_target = "//installed:{}/aws".format(version_dir)

    build_content = """\
# Generated by aws/repositories.bzl
load("@rules_aws//aws:toolchain.bzl", "aws_toolchain")
aws_toolchain(name = "aws_toolchain", target_tool_path = "{}")
alias(name = "aws", actual = "{}", visibility = ["//visibility:public"])
""".format(target_tool_path, aws_target)

    # Base BUILD file for this repository
    rctx.file("BUILD.bazel", build_content)

    rctx.file("installed/BUILD.bazel", """\
# Generated by aws/repositories.bzl
package(default_visibility=["//visibility:public"])

_SRCS = glob(["{v}/**"])

exports_files(_SRCS)

filegroup(
    name = "srcs",
    srcs = _SRCS,
)

alias(
    name = "aws_cli_layer",
    actual = "//layer:aws_cli_layer",
)
""".format(v = version_dir))

    # The container layer lives in its own package so that running the CLI doesn't load
    # @tar.bzl, which WORKSPACE users don't have.
    rctx.file("layer/BUILD.bazel", """\
# Generated by aws/repositories.bzl
load("@tar.bzl//tar:mtree.bzl", "mtree_spec")
load("@tar.bzl//tar:tar.bzl", "tar")

package(default_visibility=["//visibility:public"])

mtree_spec(
    name = "mtree",
    srcs = ["//installed:srcs"],
)

# "install" files from unpacked location
genrule(
    name = "mutate",
    srcs = [":mtree"],
    outs = [":mutated"],
    cmd = "sed 's#installed/{v}#usr/local/aws-cli#' <$< >$@",
)

tar(
    name = "aws_cli_layer",
    srcs = ["//installed:srcs"],
    mtree = ":mutated",
)
""".format(v = version_dir))

aws_repositories = repository_rule(
    _aws_repo_impl,
    doc = _DOC,
    attrs = _ATTRS,
)

def _aws_alias_impl(rctx):
    rctx.file("BUILD.bazel", """\
load("@bazel_skylib//rules:native_binary.bzl", "native_binary")

native_binary(
    name = "aws",
    src = select(
        {{
            "@bazel_tools//src/conditions:linux_x86_64": "{0}_linux-x86_64//:aws",
            "@bazel_tools//src/conditions:linux_aarch64": "{0}_linux-aarch64//:aws",
            "@bazel_tools//src/conditions:darwin_x86_64": "{0}_darwin//:aws",
            "@bazel_tools//src/conditions:darwin_arm64": "{0}_darwin//:aws",
            "@bazel_tools//src/conditions:windows": "{0}_windows//:aws",
        }},
    ),
    # Windows only runs files with an executable extension.
    out = select(
        {{
            "@bazel_tools//src/conditions:windows": "aws.bat",
            "//conditions:default": "aws",
        }},
    ),
    visibility = ["//visibility:public"],
)
""".format("@@" + rctx.name))

aws_alias = repository_rule(
    _aws_alias_impl,
    doc = "Create a repository that provides the AWS CLI aliases for host platforms",
    attrs = {},
)

# Wrapper macro around everything above, this is the primary API
def aws_register_toolchains(name, register = True, **kwargs):
    """Convenience macro for users which does typical setup.

    - create a repository for each built-in platform like "aws_linux_amd64" -
      this repository is lazily fetched when aws is needed for that platform.
    - TODO: create a convenience repository for the host platform like "aws_host"
    - create a repository exposing toolchains for each platform like "aws_platforms"
    - register a toolchain pointing at each platform
    Users can avoid this macro and do these steps themselves, if they want more control.
    Args:
        name: base name for all created repos, like "aws1_14"
        register: whether to call through to native.register_toolchains.
            Should be True for WORKSPACE users, but false when used under bzlmod extension
        **kwargs: passed to each aws_repositories call, e.g. aws_cli_version and integrity_hashes
    """
    aws_alias(name = name)
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
