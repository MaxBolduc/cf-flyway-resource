FROM boxfuse/flyway:5.2.4

RUN apt-get update \
    && apt-get install -y dialog \
    && apt-get install -y apt-utils \
    && apt-get install -y apt-transport-https \
    && apt-get install -y ca-certificates \
    && apt-get install -y jq

    # ...first add the Cloud Foundry Foundation public key and package repository to your system
RUN wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | apt-key add -

    # ...then, update your local package index, then finally install the cf CLI
RUN echo "deb https://packages.cloudfoundry.org/debian stable main" | tee /etc/apt/sources.list.d/cloudfoundry-cli.list

RUN apt-get update \
    && apt-get install -y cf-cli

COPY ./opt/resource /opt/resource

WORKDIR /opt/resource

RUN ln -s ./check.sh ./check \
    && ln -s ./in.sh ./in \
    && ln -s ./out.sh ./out
