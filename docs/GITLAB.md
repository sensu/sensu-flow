## GitLab
You can use the `sensu/sensu-flow` docker image [docker image](https://docs.gitlab.com/ee/ci/docker/using_docker_images.html#define-image-in-the-gitlab-ciyml-file) with GitLab
Please note, it's a good idea to use GitLab's support for [Vault Secrets](https://docs.gitlab.com/ee/ci/yaml/index.html#secrets) for sensitive authentication variables such as the Sensu api key or password.

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
