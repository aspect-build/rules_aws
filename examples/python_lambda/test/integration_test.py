import json

import docker
import pytest
import requests
from testcontainers.core.container import DockerContainer

TAR_PATH = "examples/python_lambda/tarball/tarball.tar"
IMAGE_NAME = "aws_lambda_hello_world:latest"


def _load_latest_tarball():
    """
    Load latest image to local Docker images

    This will load the latest tarball to Docker
    So that we run the test against the latest image
    """
    client = docker.from_env()
    with open(TAR_PATH, "rb") as f:
        client.images.load(f)


def test_thing():
    _load_latest_tarball()

    with DockerContainer(
        IMAGE_NAME,
    ).with_bind_ports(
        container=8080,
        host=9000,
    ) as container:
        # get_exposed_port waits for the container to be ready
        # https://github.com/testcontainers/testcontainers-python/blob/2bcb931063e84da1364aa26937778f0e45708000/core/testcontainers/core/container.py#L107-L108
        port = container.get_exposed_port(8080)
        data = json.dumps({})
        res = requests.post(
            f"http://localhost:{port}/2015-03-31/functions/function/invocations",
            data=data,
        )
        assert res.json().startswith("Hello from AWS Lambda using Python3")
