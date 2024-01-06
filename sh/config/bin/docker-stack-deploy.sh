#!/bin/sh

env $(cat .env | grep ^[A-Z] | xargs) docker stack deploy --compose-file $1 $2