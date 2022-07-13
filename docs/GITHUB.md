## GitHub

You can use SensuFlow to manage Sensu resources as part of GitHub-facilitated CI/CD workflows.
SensuFlow was originally designed as a GitHub action.

### Authentication

The `sensuflow.sh` script requires the SENSU_API_KEY and SENSU_API_URL [environment variables][3] for authentication.

The SENSU_API_KEY is the Sensu [API key for your sensu-flow service account user][4].
The SENSU_API_URL is the Sensu backend URL used to configure sensuctl.
For example, if your Sensu backend is hosted at `93.184.216.34` on port `8080`, the SENSU_API_URL is `http://93.184.216.34:8080`.

We recommend using [GitHub Actions secrets][3] for sensitive information like authentication credentials.

### Configure the SensuFlow GitHub Action

Use this GitHub Action as part of a GitHub Action workflow YAML definition.
GitHub Action workflow definitions are placed in `.github/workflows/` in your code repository and must exist in the default branch.
Read the [GitHub Actions documentation][2] for more information.

### Example GitHub Action

This section describes a working example that will run the SensuFlow GitHub Action when you push to the `main` branch of your code repository or when anyone creates a pull request against the `main` branch.

1. Save the following code as `.github/workflows/sensu-flow.yaml` and commit it to the `main` branch of your code repository:

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

    # Step 2: use the versioned sensu/sensu-flow action 
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

2. Add the following definition for a new Sensu namespace resource to the file `.sensu/cluster/namespaces.yaml` in your code repository:

```
---
type: Namespace
api_version: core/v2
spec:
  name: test-namespace
```

3. Create a corresponding namespace directory for the new `test-namespace` resource:

```
mkdir -p .sensu/namespaces/test-namespace
touch .sensu/namespaces/.keep
``` 

The SensuFlow GitHub Action will process the `test-namespace` directory, using any resource definitions it finds within that directory as a source of truth for the state of the corresponding Sensu namespace.
The `.keep` file tells git to keep the directory structure as part of the repository even if there are no files defined in it.

4. Create `checks` and `handlers` subdirectories within the `test-namespace` directory:
```
mkdir .sensu/namespaces/test-namespace/checks
mkdir .sensu/namespaces/test-namespace/handlers
``` 

5. Create a file named `.sensu/namespaces/test-namespace/checks/hello_world.yaml` and save the following check resource in it:

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

5. Create a file named `.sensu/namespaces/test-namespace/handlers/test.yaml` and save the following handler resource in it:

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

6. Commit and push the changes to your GitHub code repository.
The SensuFlow GitHub Action should trigger and run to completion.

7. As the administrative user for your Sensu environment, verify that the `test-namespace` namespace exists:

```
sensuctl namespace list
```

8. Verify that the `hello-world` check, and `test` handler were created within the `test-namespace`:

```
sensuctl --namespace test-namespace check list
sensuctl --namespace test-namespace handler list
```

9. Delete the file `.sensu/namespaces/test-namespace/checks/hello_world.yaml` in your Sensu environment.

10. Commit and push the change to you rGitHub code repository.
The SensuFlow GitHub Action will use `sensuctl prune` to remove the `hello-world` check.

11. Verify that the `hello-world` check no longer exists in the `test-namespace`:

```
sensuctl --namespace test-namespace check list
```


[1]: https://docs.github.com/en/github-ae@latest/actions/security-guides/encrypted-secrets
[2]: https://docs.github.com/en/github-ae@latest/actions
[3]: ../#configuration
[4]: ../#api-key-for-the-sensu-flow-user
