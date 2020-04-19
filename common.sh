#!/usr/bin/env bash

# This file regroups common function used in scripts

# indicates if the current node is part of a swarm cluster
function isSwarmNode() {
    if [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" == "inactive" ]; then
        false
        return
    else
        true
        return
    fi
}

