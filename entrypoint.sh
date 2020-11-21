#!/bin/sh
preflight_check=0
WORKFLOW_LABEL_SELECTOR="sensu.io/workflow == sensu_flow"
MANAGED_RESOURCES="checks,handlers,filters,mutators,assets,secrets/v1.Secret,roles,role-bindings"
NAMESPACES_DIR="namespaces"

echo "Working Directory: $PWD"
if [ -f  ./.env ] ; then
  source ./.env
fi

[ -z "$SENSU_USER" ] && [ -z "$INPUT_SENSU_USER" ] && echo "SENSU_USER environment variable empty" && preflight_check=1
[ -z "$SENSU_PASSWORD" ] && [ -z "$INPUT_SENSU_PASSWORD" ] && echo "SENSU_PASSWORD environment variable empty" && preflight_check=1
[ -z "$SENSU_BACKEND_URL" ] && [ -z "$INPUT_SENSU_BACKEND_URL" ] && echo "SENSU_BACKEND_URL environment variable empty" && preflight_check=1

[ -z "$WORKFLOW_LABEL_SELECTOR" ] && [ -z "$INPUT_WORKFLOW_LABEL_SELECTOR" ] && echo "WORKFLOW_LABEL_SELECTOR environment variable empty" && preflight_check=1
[ -z "$MANAGED_RESOURCES" ] && [ -z "$INPUT_MANAGED_RESOURCES" ] && echo "MANAGED_RESOURCES environment variable empty" && preflight_check=1
[ -z "$NAMESPACES_DIR" ] && [ -z "$INPUT_NAMESPACES_DIR" ] && echo "NAMESPACES_DIE environment variable empty" && preflight_check=1

if test $preflight_check -ne 0 ; then
	echo "Missing environment variables"
	exit 1
else
	echo "All needed environment variables are available"
fi

if [ -z "$INPUT_SENSU_USER" ] ; then
	username=$SENSU_USER
else
	username=$INPUT_SENSU_USER
fi
if [ -z "$INPUT_SENSU_PASSWORD" ] ; then
	password=$SENSU_PASSWORD
else
	password=$INPUT_SENSU_PASSWORD
fi
if [ -z "$INPUT_SENSU_COMMAND" ] ; then
	cmd=$SENSU_COMMAND
else
	cmd=$INPUT_SENSU_COMMAND
fi
if [ -z "$INPUT_SENSU_BACKEND_URL" ] ; then
	url=$SENSU_BACKEND_URL
else
	url=$INPUT_SENSU_BACKEND_URL
fi
if [ -z "$INPUT_CONFIGURE_ARGS" ] ; then
	optional_args=$CONFIGURE_ARGS
else
	optional_args=$INPUT_CONFIGURE_ARGS
fi
if [ -z "$INPUT_SENSU_CA" ] ; then
	ca_file=$SENSU_CA
else
	ca_file=$INPUT_SENSU_CA
fi

if [ -z "$INPUT_WORKFLOW_LABEL_SELECTOR" ] ; then
        label_selector=$WORKFLOW_LABEL_SELECTOR
else
        label_selector=$INPUT_WORKFLOW_LABEL_SELECTOR
fi

if [ -z "$INPUT_MANAGED_RESOURCES" ] ; then
	managed_resources=$MANAGED_RESOURCES
else
        managed_resources=$INPUT_MANAGED_RESOURCES
fi
if [ -z "$INPUT_NAMESPACES_DIR" ] ; then
	namespaces_dir=$NAMESPACES_DIR
else
        namespaces_dir=$INPUT_NAMESPACES_DIR
fi

if [ -z "$ca_file" ] ; then
	touch /tmp/sensu_ca.pem  
else
	echo $ca_file > /tmp/sensu_ca.pem  
fi

if [ -s /tmp/sensu_ca.pem ]; then
        echo "custom CA file present"
	ca_arg='--trusted-ca-file /tmp/sensu_ca.pem'
else
 	ca_arg=''
fi

echo "Configuring sensuctl:"
sensuctl configure -n --username ${username} --password ${password} --url ${url} ${ca_arg}  ${optional_args}
retval=$?
sensuctl config view
if test $retval -ne 0; then
	echo "sensuctl configure failed"
	exit $retval
fi
echo "Current Directory:"
pwd

echo "Executing Sensuflow"
# Functions

# Display error message and exit
function die {
  echo "$1"
  exit 1
}

# Check if a namespace exists
function is_namespace {
  QUERY=$(sensuctl namespace list --format json | jq  -r ".[] | select(.name==\"${1}\") | .name")
  test "${1}" = "${QUERY}"
  return $?
}

# Main

# First, make sure we have our namespaces
if test -f namespaces.yaml
then
  sensuctl create -f namespaces.yaml
fi

cd $namespaces_dir || die "Failed to cd to namespaces directory!"
echo "Namespaces Directory: $(pwd)"

for namespace in $(ls -1)
do
  # If not a directory of resources then skip
  if ! test -d ${namespace}
  then
     echo "${namespace} in $namespaces_dir/ is not a directory, skipping"
     continue
  fi

  if ! is_namespace ${namespace}
  then
     # Skip or die?
     # Skip means this may pass silently, die would cause bad exit
     # that should cause a build failure
     echo "Directory ${namespace} exists in namespaces/ but is not a defined namespace in sensu, skipping"
     continue
  fi

  echo "Namespace ${namespace}"
  echo -e "Pruning resources...\c"
  NUM=$(sensuctl prune ${MANAGED_RESOURCES} --namespace ${namespace} --label-selector "${WORKFLOW_LABEL_SELECTOR}" -r -f ${namespace} | jq '. | length')
  echo "${NUM} resources deleted"

  echo -e "Creating/Updating resources...\c"
  # Would be really nice if this gave us some type of output
  sensuctl create -r -f ${namespace} --namespace ${namespace}
  echo -e "Done\n"

done


