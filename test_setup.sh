#!/bin/bash
docker build -t debian_embedded-device-manager .
docker run -it --rm debian_embedded-device-manager sh
