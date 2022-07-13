## GitLab

You can use the `sensu/sensu-flow` [Docker container image][2] with [GitLab CI/CD][1].

### Authentication

The `sensuflow.sh` script requires the SENSU_API_KEY and SENSU_API_URL [environment variables][4] for authentication.

The SENSU_API_KEY is the Sensu [API key for your sensu-flow service account user][6].
The SENSU_API_URL is the Sensu backend URL used to configure sensuctl.
For example, if your Sensu backend is hosted at `93.184.216.34` on port `8080`, the SENSU_API_URL is `http://93.184.216.34:8080`.

Although you can add the SENSU_API_KEY and SENSU_API_URL directly to your `.gitlab-ci.yml` file, we recommend using [GitLab CI/CD secrets][3] for sensitive information like authentication credentials.

### Example GitLab CI/CD job definition

Here's a reference example for a GitLab CI/CD job definition that uses the `sensu/sensu-flow` Eocker image with an api-key seeded into a vault.

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


[1]: https://docs.gitlab.com/ee/ci/docker/using_docker_images.html#define-image-in-the-gitlab-ciyml-file
[2]: https://hub.docker.com/repository/docker/sensu/sensu-flow
[3]: https://docs.gitlab.com/ee/ci/yaml/index.html#secrets
