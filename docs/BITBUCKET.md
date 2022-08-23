## Bitbucket
The `sensu/sensu-flow` [Docker container image](https://docs.gitlab.com/ee/ci/docker/using_docker_images.html#define-image-in-the-gitlab-ciyml-file) can be used with Bitbucket pipelines. The `sensuflow.sh` script within this container was originally developed for GitHub actions, but will execute successfully if provided the correct environment variables.

### Authentication

The `sensuflow.sh` script will look for a `SENSU_API_URL` and `SENSU_API_KEY` to use for authentication, and while it is possible to add these directly to your `bitbucket-pipelines.yml` file, we recommend using [Bitbucket repository variables](https://support.atlassian.com/bitbucket-cloud/docs/variables-and-secrets/) in order to keep your credentials from being tracked by git. 

To set repository variables, from your repository's page on Bitbucket, click on "Repository settings" on the left-hand menu. From there, click on "Repository variables," also on the left-hand menu.

On the resulting page, in the "Name" input bux, put `SENSU_API_URL`. Set the "Value" input box to be the API URL of your backend. For example, if your Sensu backend is hosted at `93.184.216.34` on port `8080`, you would set `SENSU_API_URL` to `http://93.184.216.34:8080`. Leave the "Secured" checkbox checked, and click the "Add" button.

After that is done, you will add `SENSU_API_KEY` in the same way. To generate your API key, in an environment where you have `sensuctl` configured, run `sensuctl api-key grant sensu-flow`. This will output a string such as the following.

```
/api/core/v2/apikeys/4b044eea-9937-4e83-b263-2f6cd0431e9c
```

The final part, `4b044eea-9937-4e83-b263-2f6cd0431e9c` is what you will set as the value of `SENSU_API_KEY`. If you encounter an error, make sure that a `sensu-flow` user has been created [as is specified](https://github.com/sensu/sensu-flow#create-the-sensu-flow-user) in this repository's main documentation.

### Other Configuration Options

The following environment variables are taken into account by `sensuflow.sh`. You can either set them using Bitbucket repository variables in the same way as described in the "Authentication" section above, or you can set them directly in your script by executing `export VARIABLE=VALUE`. For example, to set `VERBOSE` to `1`, you would add `export VERBOSE=1` to your pipeline script.

* `SENSU_CA` - CA certificate as a string.
* `SENSU_CA_FILE` - CA certificate file, if set overrides `SENSU_CA`.
* `CONFIGURE_OPTIONS` - Additional sensuctl configure options.
* `NAMESPACES_DIR` - Directory holding sensuflow namepace subdirectories.
* `NAMESPACES_FILE` - File holding namespace resource definitions sensuflow action should create.
* `MANAGED_RESOURCES` - A comma seperated list of resources.
* `MATCHING_LABEL` - A resource label to match.
* `MATCHING_CONDITION` - Condition to match.
* `RESOURCE_AUTHORS` - user names to match in the created_by metadata when pruning resources.
* `DISABLE_SANITY_CHECKS` - If set sanity checks will be disabled.
* `DISABLE_TLS_VERIFY` - If TLS verification will be disabled.
* `VERBOSE` - If set shows verbose description of actions carried out by the script.

### Example Pipeline

Create a file named `bitbucket-pipelines.yml` in the root folder of your project with the following contents, and edit it as needed. The example below is set to show verbose output, and to load the credentials necessary for authentication from Bitbucket repository variables. 

```yaml
image: sensu/sensu-flow:0.7.0

pipelines:
  default:
    - step:
        name: 'Sensuflow with required settings'
        script:
          - "export VERBOSE=1"
          - "/sensuflow.sh"
```
