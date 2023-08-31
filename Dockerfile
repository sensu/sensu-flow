# Container image that runs your code
FROM sensu/sensu:latest
RUN apk add --update-cache jq yq curl

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY sensuflow.sh /sensuflow.sh
# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/sensuflow.sh"]

