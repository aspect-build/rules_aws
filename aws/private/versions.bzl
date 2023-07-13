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
        "linux-aarch64": ("awscli-exe-linux-aarch64-{}.zip", "sha384-BK0N/bcz4CdDs3Ntf9/diqHpW/b3TdDomyJGP1VOtFC1ZIzjAP1UnIHrN1h/iwze"),
        "linux-x86_64": ("awscli-exe-linux-x86_64-{}.zip", "sha384-qXEtDydyIB0C0sfMarp9EXoc5LpxLOMgMMx0LQMXhMJmBX3hq747KC63TcduHsoK"),
        "darwin": ("AWSCLIV2-{}.pkg", "sha384-l+L9FfR/H0lcjwnprTS/lC5xi04QeUOID2LgAZw1CocoPM3D1sEAXQwz5oBAzpyP"),
        "win32": ("AWSCLIV2-{}.msi", "sha384-OVKtCKMkuYzMsALVQT/lf/YvWHUbBUVK/dGZemdIAZI30pM919untzJEyJ4EmJnT"),
    },
}
