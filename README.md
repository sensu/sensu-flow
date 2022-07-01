# SensuFlow GitHub Action
The GitHub Action for SensuFlow, a git-based approach to managing Sensu resources.

## Introduction
This GitHub Action will allow you to manage Sensu resources for multiple Sensu namespaces as part of GitHub-facilitated CI/CD workflows.
 
In order to use this action, you'll first need to define a Sensu user and associated role-based access control. A reference RBAC policy and user definition matching the Action's default settings is provided below as a reference. 


## How It Works
This Action provides an opinionated best practises to using the `sensuctl create` and `sensuctl prune` commands in order to efficiently manage Sensu monitoring resources in one or more namespaces. The Action automates several resource linting actions to help ensure self-consistent monitoring resources are defined prior to updating any Sensu resources.

This is achieved by processing a directory structure where each subdirectory is mapped to a Sensu namespace.
By default, the required directory structure looks like:
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
where `<namespace>` is a placeholder for each Sensu namespace under management. The `cluster/` directory can be used to optionally manage Sensu cluster-wide resources, such as namespaces, if the Sensu RBAC profile in use allows for cluster-wide resource management.
  
## Setup

### Configure the Sensu RBAC Profile
Below are instructions to create an RBAC profile that can be used with this Action with the default settings. This profile makes use of Sensu CluserRole and ClusterRoleBindings to grant the Action user access to a subset of Sensu resources cluster-wide. You may want to use a more restrictive RBAC policy to meet your security requirements.

You will need to run these commands in an environment where sensuctl is pre-configured to communicate with the Sensu backend you want SensuFlow to work with.

#### Create the sensu-flow ClusterRole
The Sensu ClusterRole defines the resource permissions the GitHub resource will need.
```
$ sensuctl cluster-role create sensu-flow \
  --resource namespaces,roles,rolebindings,assets,handlers,checks,hooks,filters,mutators,secrets \
  --verb get,list,create,update,delete
```

#### Create the sensu-flow ClusterRoleBinding
The Sensu ClusterRoleBinding connects the ClusterRole to a group of users.
```
$ sensuctl cluster-role-binding create sensu-flow \
  --cluster-role sensu-flow \
  --group sensu-flow
```

#### Create the sensu-flow User
A Sensu user and password is needed to authenticate with the Sensu API. Make sure the user is a member of the `sensu-flow` group.

Create the user interactively:
```
$ sensuctl user create --interactive
? Username: sensu-flow
? Password: *********
? Groups: sensu-flow
Created
```

or, create the user non-interactively:
```
$ sensuctl user create sensu-flow \
  --password REPLACEME \
  --groups sensu-flow

```

### Configure the SensuFlow GitHub Action
In order to make use of this GitHub Action you will need to use it as part of a GitHub Action workflow YAML definition. GitHub Action workflow definitions are placed in `.github/workflows/` in your repository and must exist in the default branch. Please see the GitHub Action documentation for specifics.


The action requires 2 configuration options to be defined:
```
sensu_api_url
sensu_api_key
```
All other configuration options are considered optional.

You will also want to consider using GitHub secrets for sensitive information used in the Action configuration. At a minimum, you will want to consider using GitHub secrets for the `sensu_user` and `sensu_password`.

### Verifying Configuration
Below is a working example that will run the SensuFlow GitHub Action when pushing to main branch or when a main branch pull-request is created.

#### GitHub Action Workflow Example
Save as `.github/workflows/sensu-flow.yaml` and commit to main branch. After activating the workflow in the GitHub UX, this Action should run for any commits into main.

```
name: SensuFlow CI Example

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  # Defined the SensuFlow job 
  SensuFlow:
    runs-on: ubuntu-latest
    steps:
    # Step 1: Checks-out your repository, so your job can access it
    - name: Checkout
      uses: actions/checkout@v2

    # Step 2: use the versioned sensu/sensuflow action 
    - name: Sensuflow with required settings
      uses: sensu/sensu-flow@0.6.0
      with:
        # Required configuration
        # Please make use of GitHub secrets for sensitive information 
        sensu_api_url: ${{ secrets.SENSU_API_URL }}
        sensu_api_key: ${{ secrets.SENSU_API_KEY }}
        # Optional configuration, if not present defaults will be used
        namespaces_dir: .sensu/namespaces
        namespaces_file: .sensu/cluster/namespaces.yaml
        matching_label: "sensu.io/workflow"
        matching_condition: "== 'sensu-flow'"

```
### Your First SensuFlow Workflow
Now that the action is activated and configured to run on any push into the main branch, you can test it.

#### Create a Test Namespace
Edit the file `.sensu/cluster/namespaces.yaml` in your git repository and define a Sensu namespace resource for a new testing namespace.
```
---
type: Namespace
api_version: core/v2
spec:
  name: test-namespace
```

### Create Corresponding Namespace Directory
```
mkdir -p .sensu/namespaces/test-namespace
touch .sensu/namespaces/.keep
``` 

The SensuFlow GitHub Action will process the `test-namespace` directory, using resource definitions found within as a source of truth for the state of the corresponding Sensu namespace. The `.keep` file just tells git to keep the directory structure as part of the repository even if there are no files defined in it.  

### Create Initial Resources in test-namespace
mkdir `.sensu/namespaces/test-namespace/checks`
edit the file `.sensu/namespaces/test-namespace/checks/hello_world.yaml`
```
type: CheckConfig
api_version: core/v2
metadata:
  name: hello_world
  labels:
    sensu.io/workflow: sensu-flow
spec:
  command: echo "hello world"
  interval: 30
  publish: false
  subscriptions:
  - test
  timeout: 10
```

mkdir `.sensu/namespaces/test-namespace/handlers`
edit the file `.sensu/namespaces/test-namespace/handlers/test.yaml`
```
type: Handler
api_version: core/v2
metadata:
  name: test
  labels:
    sensu.io/workflow: sensu-flow
spec:
  command: sleep 10
  type: pipe
```

### Commit and Push Changes
Once these files are in place, you can commit and push the changes back to GitHub. The SensuFlow GitHub Action should trigger and run to completion.
You can then verify using sensuctl in your administrative environment that the test-namespace exists.
```
sensuctl namespace list
```
and that the namespace contains the hello-world check and the test handler
```
sensuctl --namespace test-namespace check list
sensuctl --namespace test-namespace handler list
```
### Delete the Check From the Git Repository
Now delete the `hello_world.yaml` file and commit the change again. The SensuFlow GitHub Action will use `sensuctl prune` to remove the check and you should be able to verify that the check no longer exists in the test-namespace.


## GitHub Action Configuration Reference

### Namespace Resource Management
This action uses a special directory structure, mapping subdirectory names to Sensu namespaces to process. By default the directory processed is `.sensu/namespaces/` but this can be overridden in the Action configuration. If this directory exists, each subdirectory will be processed as a separate Sensu namespace. Example directory structure:
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
        ├── handlersets
        │   └── alert.yaml
        ├── handlers
        │   ├── aws-sns.yaml
        │   └── pushover.yaml
        └── mutators
            └── check-status.yaml
```

Using this example, this Action would process the `test-namespace`, pruning the namespace resources according to `matching_label`, `matching_condition`,  and `managed_resources`settings

### Optionally Preparing Namespaces
If the namespaces file (default: `.sensu/cluster/namespaces.yaml`) exists and is populated with Sensu namespace resource definitions, then this Action will be used to create the Sensu namespace resources defined in the file before attempting to process the namespaces directory. 

Note: Namespaces are a cluster-level resource, so in order to use the namespaces creation capability the Sensu user will need cluser-level role-based access to create namespaces.  

## Configuration
### Required settings
#### sensu_api_url 
  The Sensu API url, same as `sensuctl` uses ( ex: `https://sensu.example.com:8080` )
### Authentication settings
#### sensu_api_key
  A [Sensu API key](https://docs.sensu.io/sensu-go/latest/operations/control-access/use-apikeys/#sensuctl-management-commands)
_OR_
#### sensu_user (deprecated) 
  The Sensu user to auth 
#### sensu_password (deprecated)
  The Sensu user password


### Optional settings
####  configure_args:
    description: optional arguments to pass to sensuctl configure
####  sensu_ca_string:
    description: Optional Custom CA pem string. Use this if you want to encode the CA pem as a github secret
####  sensu_ca_file:
    description: Optional Custom CA file location, this will override sensu_ca_string if used
####  namespaces_dir:
    description: Optional directory to process default: ".sensu/namespaces"
####  namespaces_file:
    description: Optional YAML file containing Sensu namespace resources to create default ".sensu/cluster/namespaces.yml"
####  matching_label:
    description: Optional Sensu label selector, default: "sensu.io/workflow"
####  matching_condition:
    description: Optional Sensu label matching condition, default: "== 'sensu-flow'"
####  managed_resources:
    description: Optional comma seperated list of managed resources, default: "checks,handlers,filters,mutators,assets,secrets/v1.Secret,roles,role-bindings,core/v2.HookConfig"
####  disable_tls_verify:
    description: Optional boolean argument to to disable tls cert verification  default: false
####  disable_sanity_checks:
    description: Optional boolean argument to to disable sanity checks  default: false    


## Using the Docker container image with other CI/CD tools
While this is originally developed and tested for use with GitHub Actions, there is a vendor neutral `sensu/sensuflow` [Docker](https://hub.docker.com/repository/docker/sensu/sensu-flow) container image available as of version `0.6.0` that should be suitable for use with any CI/CD tool chain that is capable of using container images for CI/CD jobs. Here's a list of contributed instructions for alternative CI/CD vendors: 


* [GitLab](docs/GITLAB.md)

Contributed instructions for additional CI/CD services are welcome.
 
## Goals 

SensuFlow is under active development, so please don't hesitate to submit issues for any enhancements you'd like to see. 

The main improvements we're currently focused on at the time of this writing (H1'21) are as follows: 

- Improved pre-flight tests (test Sensu endpoint liveness, verify authentication credentials, etc.)
- Improved linting (label enforcement, type validation, etc.)
- Validate integrity of assets (optionally fetch all configured assets, verify SHA512 values)
- Reference testing (if a check/handler refers to assets and/or secrets, are the asset/secret resource definitions also present?)

For more information, please view the SensuFlow project [issues][issues] and [milestones][milestones]. 

[issues]: https://github.com/sensu/sensu-flow/issues 
[milestones]: https://github.com/sensu/sensu-flow/milestones

