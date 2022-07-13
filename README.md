# SensuFlow

SensuFlow is a prescriptive monitoring as code workflow that uses the Sensu Go API and sensuctl commands to synchronize Sensu resources for multiple Sensu namespaces as part of a CI/CD system.
Specifically, SensuFlow executes [`sensuctl create`][19] and [`sensuctl prune`][20] commands.
Use SensuFlow to ensure that updates to the Sensu resources in your repository are reflected in your Sensu configuration.

SensuFlow is implemented as a Bash shell script, `sensuflow.sh`, that executes sensuctl commands in a Docker container.
SensuFlow includes linting logic to ensure your Sensu resource definitions are self-consistent with respect to your namespace directory structure and label-matching rule.

## Requirements

The SensuFlow script requires these executables:

- [jq][10]
- [yq][11]
- [sensuctl][12] (configured to communicate with the Sensu backend that you want to use SensuFlow with)

To use SensuFlow, you'll also need:

- A Sensu role-based access control (RBAC) [service account][13] with sufficient privileges to manage your monitoring configuration as code.
- A [resource labeling][14] convention to designate which resources should be managed by SensuFlow.
- A repository that contains Sensu monitoring code, organized in the correct [directory structure][15].
- An integrated CI/CD system to run sensuctl commands using the Sensu service account from your Sensu monitoring code repository.

A vendor-neutral `sensu/sensu-flow` [Docker container image][1] is available as of version `0.6.0`.
You can use the Docker container image in your local development environment or adapt it to use with any CI/CD service that can use container images for CI/CD jobs.
More information is available for the following CI/CD services: 

- [Bitbucket][4]
- [GitHub][5]
- [GitLab][6]

## Install SensuFlow

**TODO**

## Service account

This section explains how to create a service account for use with SensuFlow.
The commands in this section will create an example service account with a [cluster role][16], [cluster role binding][17], and [user][18].
You can use this example service account with the default SensuFlow settings.

**NOTE**: Run these commands in an environment where sensuctl is already configured to communicate with the Sensu backend that SensuFlow should work with.

1. Create the sensu-flow cluster role, which defines the resource permissions the sensu-flow service account will need:

```
sensuctl cluster-role create sensu-flow \
--resource namespaces,roles,rolebindings,assets,handlers,checks,hooks,filters,mutators,secrets \
--verb get,list,create,update,delete
```

2. Create the sensu-flow cluster role binding, which connects the cluster role to a group of users:

```
sensuctl cluster-role-binding create sensu-flow \
--cluster-role sensu-flow \
--group sensu-flow
```

3. Create the sensu-flow user.
A Sensu user and password is required to authenticate with the Sensu API.
Make sure the user is a member of the `sensu-flow` group.

    To create the user interactively:
```
sensuctl user create --interactive
? Username: sensu-flow
? Password: <your_password>
? Groups: sensu-flow
```

    To create the user non-interactively:
```
sensuctl user create sensu-flow \
--password <your_password> \
--groups sensu-flow
```

**NOTE**: The example service account grants the sensu-flow user access to a subset of Sensu resources, cluster-wide.
You may prefer to use a more restrictive RBAC policy to meet your security requirements.
Read [Create limited service accounts][7] and the [Role based access control][8] reference for more information.

### API key for the sensu-flow user

The sensu-flow user must have an API key to authenticate to the Sensu APIs required to use SensuFlow.

To generate an API key, in your environment where `sensuctl` is configured, run `sensuctl api-key grant sensu-flow`.
The response will include a string like `/api/core/v2/apikeys/4b044eea-9937-4e83-b263-2f6cd0431e9c`.
The last part of the string, in this case `4b044eea-9937-4e83-b263-2f6cd0431e9c`, is the API key.

If you encounter an error, make sure that you have created a `sensu-flow` [service account][13] user.

## Resource labeling

To determine which Sensu resources to act upon, SensuFlow compares the settings for MATCHING_LABEL, MATCHING_CONDITION, and MANAGED_RESOURCES against each resource definition.
For SensuFlow to act on a resource, all of the following must be true:

- The resource includes the label specified as the MATCHING_LABEL value.
- The resource's value for the label evaluates to true according to the specified MATCHING_CONDITION.
- The resource type is listed among the specified MANAGED_RESOURCES.

For example, suppose you set the following SensuFlow environment variables:

- MATCHING_LABEL="sensu.io/workflow"
- MATCHING_CONDITION="== 'sensu-flow'"
- MANAGED_RESOURCES="checks,handlers,filters,mutators,assets,secrets/v1.Secret,roles,role-bindings,core/v2.HookConfig"

In this case, a Sensu check resource with the label `sensu.io/workflow: sensu-flow` matches all three requirements for processing with SensuFlow.
A check with the label `sensu.io/workflow: monitoring-as-code` does not match.
Nor does an entity, even if it includes the `sensu.io/workflow: sensu-flow` label.

### Labeling tips

Resource labeling is a key decision point in implementing SensuFlow because `sensuctl prune` and the prune API rely on labels to determine which resources to delete if they are no longer in your code repository.
This affects **all** of your Sensu resources, not just the resources in your repository.
If unmanaged resources (resources that are not managed as code) include the label that SensuFlow uses, the unmanaged resources may be deleted as part of the SensuFlow workflow.

Make sure all of the Sensu resources you want to manage with SensuFlow include the label and value specified in the MATCHING_LABEL and MATCHING_CONDITION environment variables.
Be consistent with Sensu resource labeling throughout your organization to prevent the spread of unmanaged resources or accidental deletion.

Do not include a namespace in your resource definitions.
Namespaced resources will conflict with sensuctl’s global namespace argument taken from the SensuFlow directory structure.

## Directory structure

SensuFlow uses a prescribed directory structure that is organized by clusters and namespaces, mapping subdirectory names to Sensu namespaces to process.
All resources of each type for each namespace are saved in a single configuration file.

A prescribed directory structure helps preserve maintainability and readability and makes it easier for teams to collaborate and reuse Sensu observability pipeline solutions originally developed by other teams.

The default directory structure is:

```
.sensu/
  cluster/
    namespaces.yml
  namespaces/
    <namespace>/
      checks/
      hooks/
      filters/
      handlers/
      handelersets/
      mutators/  
```

In this structure, `<namespace>` is a placeholder for each Sensu namespace under management.

By default, the processed directory is `.sensu/namespaces/`, but you can change this in your SensuFlow configuration.
Within the specified directory, each subdirectory will be processed as a separate Sensu namespace.

The following example shows how to organize Sensu resource files within the default directory structure:

```
.sensu
└── namespaces
    └── test-namespace
        ├── checks
        │   ├── check-cpu.yaml
        │   ├── check-http.yaml
        │   ├── false.yaml
        │   └── true.yaml
        ├── filters
        │   └── fatigue-check.yaml
        ├── handlers
        │   ├── aws-sns.yaml
        │   └── pushover.yaml
        ├── handlersets
        │   └── alert.yaml
        └── mutators
            └── check-status.yaml
    └── production-namespace
        ├── checks
        │   ├── check-cpu.yaml
        │   ├── check-http.yaml
        │   ├── false.yaml
        │   └── true.yaml
        ├── filters
        │   └── fatigue-check.yaml
        ├── handlers
        │   ├── aws-sns.yaml
        │   └── pushover.yaml
        ├── handlersets
        │   └── alert.yaml
        └── mutators
            └── check-status.yaml
```

You can use the `cluster/` directory to manage Sensu cluster-wide resources, such as namespaces, if the Sensu RBAC profile in use allows for cluster-wide resource management.

### Option: Create namespaces

If your code repository includes a namespaces file (default `.sensu/cluster/namespaces.yaml`) that is populated with Sensu namespace resource definitions, SensuFlow will create the Sensu namespace resources defined in the file before attempting to process the `.sensu/namespaces/` directory. 

**NOTE**: Namespaces are a cluster-level resource.
To create namespaces with SensuFlow, the Sensu [service account][13] user will need cluster-level role-based access to create namespaces.

## Configuration

SensuFlow uses environment variables to customize how the script interacts with your environment.
The minimum required variables for SensuFlow are SENSU_API_KEY and SENSU_API_URL.
All other environment variables are optional settings that allow you to customize the SensuFlow experience.

Environment variable  | Type     | Required or Optional | Description
--------------------- | -------- | -------------------- | -----------
CONFIGURE_OPTIONS     | String   | Optional             | Additional options for the `sensuctl configure` command.
DISABLE_SANITY_CHECKS | Boolean  | Optional             | If `true`, disable checks that ensure resource definitions are self-consistent. Otherwise, `false`. Default is `false`.
DISABLE_TLS_VERIFY    | Boolean  | Optional             | If `true`, disable TLS certificate verification. Otherwise, `false`. Default is `false`.
MANAGED_RESOURCES     | String   | Optional             | Comma-separated list of resource types that SensuFlow manages. Default is `"checks,handlers,filters,mutators,assets,secrets/v1.Secret,roles,role-bindings,core/v2.HookConfig"`.
MATCHING_CONDITION    | String   | Optional             | Condition statement for a Sensu resource label match. Default is `"== 'sensu-flow'"`.
MATCHING_LABEL        | String   | Optional             | Sensu resource label to match. Default is `"sensu.io/workflow"`.
NAMESPACES_DIR        | String   | Optional             | Directory that SensuFlow should process. Default is `".sensu/namespaces"`.
NAMESPACES_FILE       | String   | Optional             | Location of YAML file that contains Sensu namespace resources that SensuFlow should create. Default is `".sensu/cluster/namespaces.yml"`.
SENSU_API_KEY         | String   | Required             | Sensu [API key][9].
SENSU_API_URL         | String   | Required             | Sensu backend API URL (the URL used to configure `sensuctl`, such as `https://sensu.example.com:8080`).
SENSU_CA              | String   | Optional             | Certificate Authority (CA) file as a string. Use the SENSU_CA variable if you want to encode the CA file as a GitHub Actions secret.
SENSU_CA_FILE         | String   | Optional             | Certificate Authority (CA) file location. The SENSU_CA_FILE value (if provided) overrides the SENSU_CA value.
VERBOSE               | Integer  | Optional             | If set, shows verbose description of actions carried out by the script. 

There are also two deprecated environment variables:

- SENSU_PASSWORD (string): The Sensu user password.
- SENSU_USER (string): The Sensu user to authenticate.

The SENSU_API_KEY environment variable replaces the SENSU_PASSWORD and SENSU_USER variables.

### Set environment variables

**TODO**

## Development goals 

SensuFlow is under active development, so please submit issues for any enhancements you'd like to see. 

Here are the needed improvements we've identified so far: 

- Improved pre-flight tests (test Sensu endpoint liveness, verify authentication credentials, etc.)
- Improved linting (label enforcement, type validation, etc.)
- Validate integrity of assets (optionally fetch all configured assets; verify SHA512 values)
- Reference testing (if a check/handler refers to assets/secrets, confirm whether the asset/secret resource definitions are also present)

For more information, read the SensuFlow project [issues][2] and [milestones][3].
We also welcome contributed instructions for additional CI/CD services.


[1]: https://hub.docker.com/repository/docker/sensu/sensu-flow
[2]: https://github.com/sensu/sensu-flow/issues 
[3]: https://github.com/sensu/sensu-flow/milestones
[4]: docs/BITBUCKET.md
[5]: docs/GITHUB.md
[6]: docs/GITLAB.md
[7]: https://docs.sensu.io/sensu-go/latest/operations/control-access/create-limited-service-accounts/
[8]: https://docs.sensu.io/sensu-go/latest/operations/control-access/rbac/
[9]: https://docs.sensu.io/sensu-go/latest/operations/control-access/use-apikeys/#sensuctl-management-commands
[10]: https://stedolan.github.io/jq/
[11]: https://github.com/mikefarah/yq
[12]: https://sensu.io/downloads
[13]: #service-account
[14]: #resource-labeling
[15]: #directory-structure
[16]: https://docs.sensu.io/sensu-go/latest/operations/control-access/rbac/#cluster-roles
[17]: https://docs.sensu.io/sensu-go/latest/operations/control-access/rbac/#cluster-role-bindings
[18]: https://docs.sensu.io/sensu-go/latest/operations/control-access/rbac/#users
[19]: https://docs.sensu.io/sensu-go/latest/sensuctl/create-manage-resources/#create-resources
[20]: https://docs.sensu.io/sensu-go/latest/sensuctl/create-manage-resources/#prune-resources
