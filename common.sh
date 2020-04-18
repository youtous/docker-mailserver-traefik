#!/usr/bin/env bash

# This file regroups common function used in scripts

# indicates if the current node is part of a swarm cluster
function isSwarmNode() {
    if [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" == "inactive" ]; then
        return 0
    else
        return 1
    fi
}

