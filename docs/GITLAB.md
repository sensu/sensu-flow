## GitLab
You can use the `sensu/sensu-flow` [Docker container image](https://docs.gitlab.com/ee/ci/docker/using_docker_images.html#define-image-in-the-gitlab-ciyml-file) with GitLab. This container image includes everything needed to run the `sensuflow.sh` script originally developed for GitHub actions. Please note, it's a good idea to use GitLab's support for [Vault Secrets](https://docs.gitlab.com/ee/ci/yaml/index.html#secrets) for sensitive authentication variables such as the Sensu api key or password.

### Important environment variables
When using the docker image with GitLab, you'll need to be aware of several environment variables used by the `sensuflow.sh` script run within the Docker container. These variables are documented in the `sensuflow.sh` header comments, but here's a quick summary for reference.

```
## Required Environment Variables
# SENSU_API_URL: sensu backend api url used by sensuctl
# SENSU_API_KEY: sensu api key for sensuctl, used instead of user and password above
## Optional Environment Variables
# SENSU_CA: CA certificate as a string
# SENSU_CA_FILE: CA certificate file, if set overrides SENSU_CA
# CONFIGURE_OPTIONS: Additional sensuctl configure options
# NAMESPACES_DIR: directory holding sensuflow namepace subdirectories
# NAMESPACES_FILE: file holding namespace resource definitions sensuflow action should create
# MANAGED_RESOURCES: comma seperated list of resources
# MATCHING_LABEL: resource label to match
# MATCHING_CONDITION: condition to match
# RESOURCE_AUTHORS: user names to match in the created_by metadata when pruning resources.
# DISABLE_SANITY_CHECKS: if set disable sanity checks
# DISABLE_TLS_VERIFY: if set disable TLS verification 
## Deprecated Authentication Environment Variables
# SENSU_USER: sensu user for sensuctl configue (deprecated, use SENSU_API_KEY)
# SENSU_PASSWORD: sensu password for sensuctl configure (deprecated, use SENSU_API_KEY)
```

### Reference GitLab CI/CD job definition
Here's a reference example for a GitLab CI/CD job definition making use of the `sensu/sensu-flow` docker image together with an api-key seeded into a vault.
```
stages:
  - deploy

.sensu_flow:
  image: sensu/sensu-flow:latest
  variables:
    MATCHING_CONDITION: "== '$CI_PROJECT_NAME'"
    SENSU_BACKEND_URL: https://sensu-api.example.com
  secrets:
    SENSU_API_KEY:
      vault: sensu/sensu-flow/api-key
      file: false
  script:
    - /sensuflow.sh

sensu_flow:
  extends: .sensu_flow
  stage: deploy
  variables:
    VERBOSE: "1"
```
