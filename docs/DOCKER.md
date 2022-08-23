## Docker image
The `sensu/sensu-flow`  [Docker container image](https://hub.docker.com/r/sensu/sensu-flow) can be used with any number of CI/CD pipelines. The `sensuflow.sh` script within this container was originally developed for GitHub actions, but will execute successfully if provided the correct environment variables.

To pull the latest tagged release of the docker image use:
```
docker pull sensu/sensu-flow:latest
```

### Authentication

The `sensuflow.sh` script in the container will use the value of the environment variables `SENSU_API_URL` and `SENSU_API_KEY` for authentication, we recommend using the secrets provider mechanism for the CI/CD system you are using in order to keep your credentials secure. Each CI/CD platform will have a different implementation mechansim. 


### Optional configuration

The following optional environment variables are also used by `sensuflow.sh`. If passed to docker run will override the default values assumed by the script.

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

### Example docker run invocation
Using the docker image from a repository following the nominal default layout.

```
docker run -e SENSU_API_KEY=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee -e SENSU_API_URL=http://WWW.XXX.YYY.ZZZ:8080 -e VERBOSE=1 -v ${PWD}/.sensu:/.sensu sensu/sensu-flow:latest
```

This the sensu-flow.sh script will execute from inside the container and will look for Sensu resources under the default NAMESPACES_DIR value of  `/.sensu/namespaces/`.  Thie bind mount `-v ${PWD}/.sensu:/.sensu` takes the repository directory `.sensu` and mounts it into the container as `/.sensu`.  The multiple `-e` arguments are setting environment variables for the sensu-flow.sh script to make use of.  You can add additional `-e` calls for the optional configuratin options to tailor operation for your workflow.


