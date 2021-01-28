# SensuFlow Github Action
The Github action for SensuFlow, a git based approach to managing Sensu resources.

## Introduction
This Github action will allow you to manage Sensu resources for multiple Sensu namespaces as part Github facilitated CI/CD workflows.
 
In order to use this action, you'll first need to define a Sensu user and associated role based access control. A reference RBAC policy and user definition, matching the the actions default settings is provided below as a reference. 


## How It Works
This action provides an opinionated best practises to using the `sensuctl create` and `sensuctl prune` commands in order to efficiently manage Sensu monitoring resources in one more namespaces. The action automates several resource linting actions to help ensure self-consistent monitoring resources are defined prior to updating any Sensu resources.

This is achieved by processing a directory structure where each subdirectory is mapped to a Sensu namespace.
By default the required directory structure looks like:
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
where `<namespace>` is a placeholder for each Sensu namespace under management.  The `cluster/` directory can be used to optionally manage Sensu Cluster wide resources such as namespaces, if the Sensu RBAC profile in use allows for cluster-wide resource management.
  
## Setup

### Configure Sensu RBAC Profile
### Configure SensuFlow Github action
### Test the Github action using dedicated namespace

## Github Action Configuration Reference

### Namespace Resource Management
This action uses a special directory structure, mapping subdirectory names to Sensu namespaces to process. By default the directory processed is `namespaces/`  but this can be overridden in the action configuration. If this directory exists, each sub directory will be processed as separate Sensu namespace. Example directory structure:
```
namespaces
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

Using this example, this action would process the `test-namespace`, pruning the namespace resources according to `matching_label`, `matching_condition`,  and `managed_resources`settings

### Optionally Preparing namespaces
If the `namespaces.yaml` file exists in the working directory (normally the top level of your repository) then this action will be used to create sensu namespaces before attempting to process the namespaces directory. 

Note: Namespaces are a cluster level resource, so in order to use the namespaces creation capability the sensu user will need cluser level role based access to create namespaces.  

## Configuration
### Required settings
#### sensu_backend_url 
  The Sensu backend url
#### sensu_user 
  The Sensu user to auth 
#### sensu_password
  The Sensu user password

### Optional settings
####  configure_args:
    description: "optional arguments to pass to sensuctl configure"
####  sensu_ca_string:
    description: 'Optional Custom CA pem string. Use this if you want to encode the CA pem as a github secret'
####  sensu_ca_file:
    description: 'Optional Custom CA file location, this will override sensu_ca_string if used'
####  namespaces_dir:
    description: "Optional directory to process default: 'namespaces' "
####  namespaces_file:
    description: "Optional YAML file containing Sensu namespace resources to create"
####  matching_label:
    description: "Option Sensu label selector, default: 'sensu.io/workflow'"
####  matching_condition:
    description: "Option Sensu label matching condition, default: '== sensu_flow'"
####  managed_resources:
    description: 'Optional comma seperated list of managed resources, default: "checks,handlers,filters,mutators,assets,secrets/v1.Secret,roles,role-bindings,core/v2.HookConfig""'
####  disable_sanity_checks:
    description: 'Optional boolean argument to to disable sanity checks  default: false'    

### Github Action Workflow Example
```
jobs:
  sensuflow:
    runs-on: ubuntu-latest

    steps:
    # Checks-out your repository under $GITHUB_WORKSPACE, so your job can access it
    - name: Checkout
      uses: actions/checkout@v2

    - name: Sensuflow with optional settings
      uses: sensu/sensuflow@v0.2.2
      with:
        sensu_backend_url: ${{ secrets.SENSU_BACKEND_URL }}
        sensu_user: ${{ secrets.SENSU_USER }}
        sensu_password: ${{ secrets.SENSU_PASSWORD }} 
        namespaces_dir: namespaces
        matching_label: "sensu.io/workflow"
        matching_condition: "== sensu_flow"

```
### RBAC Policy
Here is an example of an expansive Sensu RBAC policy and user definition  configured to use this action with default settings. You may want to use a more restrictive RBAC policy to meet your requirements. 

```
---
type: ClusterRole
api_version: core/v2
metadata:
  name: sensu_flow
spec:
  rules:
  - resources:
    - namespaces
    - roles
    - rolebindings
    - assets
    - handlers
    - checks
    - filters
    - mutators
    - secrets
    verbs:
    - get
    - list
    - create
    - update
    - delete
---
type: ClusterRoleBinding
api_version: core/v2
metadata:
  name: sensu_flow
spec:
  role_ref:
    type: ClusterRole
    name: sensu_flow
  subjects:
  - type: Group
    name: sensu_flow
---
type: User 
api_version: core/v2 
metadata:
  name: sensu_flow
spec:
  disabled: false
  username: sensu_flow
  groups: 
  - sensu_flow
```

## Adapting to other CI/CD
If you would like to adapt this for other CI/CD, take a look at the  sensuflow.sh script from this repositorory. The script should be self-documenting with regard to needed executable dependancies and information concerning environment variables used.

## Goals 

SensuFlow is under active development, so please don't hesitate to submit issues for any enhancements you'd like to see. 

The main improvements we're currently focused on at the time of this writing (H1'21) are as follows: 

- Improved pre-flight tests (test Sensu endpoint liveness, verify authentication credentials, etc)
- Improved linting (label enforcement, type validation, etc)
- Validate integrity of assets (optionally fetch all configured assets, verify SHA512 values)
- Reference testing (if a check/handler refers to assets and/or secrets, are the asset/secret resource definitions also present?)

For more information, please view the SensuFlow project [issues][issues] and [milestones][milestones]. 

[issues]: https://github.com/sensu/sensu-flow/issues 
[milestones]: https://github.com/sensu/sensu-flow/milestones

