"""Mirror of release info

TODO: generate this file from GitHub API"""

# The integrity hashes can be computed with
# shasum -b -a 384 [downloaded file] | awk '{ print $1 }' | xxd -r -p | base64

# Amazon CDN serves at urls like
# https://awscli.amazonaws.com/awscli-exe-linux-aarch64-2.0.30.zip
# https://awscli.amazonaws.com/AWSCLIV2-2.0.30.pkg
# https://awscli.amazonaws.com/AWSCLIV2-2.0.30.msi
TOOL_VERSIONS = {
    "2.13.0": {
        "linux_aarch64": ("awscli-exe-linux-aarch64-{}.zip", "sha384-xxx"),
        "linux_x86_64": ("awscli-exe-linux-x86_64-{}.zip", "sha384-qXEtDydyIB0C0sfMarp9EXoc5LpxLOMgMMx0LQMXhMJmBX3hq747KC63TcduHsoK"),
        "darwin": ("AWSCLIV2-{}.pkg", "sha384-yyy"),
        "win32": ("AWSCLIV2-{}.msi", "sha384-yyy"),
    },
}
