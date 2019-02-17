FROM ubuntu:bionic

RUN apt-get update \
    && apt-get install -y jq

COPY ./opt/resource /opt/resource

WORKDIR /opt/resource

RUN ln -s ./check.sh ./check \
    && ln -s ./in.sh ./in \
    && ln -s ./out.sh ./out
