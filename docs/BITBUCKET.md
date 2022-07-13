## Bitbucket

You can use the `sensu/sensu-flow` [Docker container image][2] with [Bitbucket pipelines][1].

### Authentication

The `sensuflow.sh` script requires the SENSU_API_KEY and SENSU_API_URL [environment variables][4] for authentication.

The SENSU_API_KEY is the Sensu [API key for your sensu-flow service account user][6].
The SENSU_API_URL is the Sensu backend URL used to configure sensuctl.
For example, if your Sensu backend is hosted at `93.184.216.34` on port `8080`, the SENSU_API_URL is `http://93.184.216.34:8080`.

Although you can add the SENSU_API_KEY and SENSU_API_URL directly to your `bitbucket-pipelines.yml` file, we recommend using [Bitbucket repository variables][3] for sensitive information like authentication credentials.

To set Bitbucket repository variables:

1. On your repository's page on Bitbucket, use the left menu to navigate to **Repository settings > Repository variables**.
Wait for the Repository variables page to load.

2. In the *Name* field, enter `SENSU_API_KEY`.

3. In the *Value* field, enter the API key for your sensu-flow service account user.

4. Ensure that the *Secured* checkbox is checked.

5. Click **Add**.

6. Repeat steps 1 through 5 for the SENSU_API_URL variable and value.

### Other Configuration Options

In addition to the required environment variables, SensuFlow includes optional environment variables.
You can set the optional environment variables with Bitbucket repository variables as described in [Authentication][7] or directly in your Bitbucket pipeline script.

To set environment variables in your Bitbucket pipeline script, add `export VARIABLE=VALUE`.
For example, to set `VERBOSE` to `1`, add `export VERBOSE=1` to your pipeline script.

### Example Bitbucket pipeline

Create a file named `bitbucket-pipelines.yml` in the root folder of your project with the following contents and edit as needed.
This example shows verbose output and loads the credentials necessary for authentication from Bitbucket repository variables. 


```yaml
image: sensu/sensu-flow:0.6.0

pipelines:
  default:
    - step:
        name: 'SensuFlow with required settings'
        script:
          - "export VERBOSE=1"
          - "/sensuflow.sh"
```


[1]: https://confluence.atlassian.com/bitbucket/use-docker-images-as-build-environments-in-bitbucket-pipelines-792298897.html
[2]: https://hub.docker.com/repository/docker/sensu/sensu-flow
[3]: https://support.atlassian.com/bitbucket-cloud/docs/variables-and-secrets/
[4]: ../#configuration
[5]: ../#create-the-sensu-flow-user
[6]: ../#api-key-for-the-sensu-flow-user
[7]: #authentication
[8]: ../#set-environment-variables
