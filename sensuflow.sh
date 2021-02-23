#!/usr/bin/env ash

###
# shell script to implement sensuflow
## External dependancies:
# sensuctl: https://sensu.io/downloads
# yq: https://github.com/mikefarah/yq/v4
# jq: https://stedolan.github.io/jq/
#
## Required Environment Variables
# SENSU_USER: sensu user for sensuctl configure
# SENSU_PASSWORD: sensu password for sensuctl configure
# SENSU_BACKEND_URL: sensu backend for sensuctl configure
## Optional Environment Variables
# SENSU_CA: CA certificate as a string
# SENSU_CA_FILE: CA certificate file, if set overrides SENSU_CA
# CONFIGURE_OPTIONS: Additional sensuctl configure options
# NAMESPACES_DIR: directory holding sensuflow namepace subdirectories
# NAMESPACES_FILE: file holding namespace resource definitions sensuflow action should create
# MANAGED_RESOURCES: comma seperated list of resources
# MATCHING_LABEL: resource label to match
# MATCHING_CONDITION: condition to match
# DISABLE_SANITY_CHECKS: if set disable sanity checks

## Github Action Notes
# Github Actions prefaces variables with INPUT_ 

## Read in envvars from .env from current directory
if [ -f  ./.env ] ; then
  source ./.env
fi

### Setup envvar values, including fallback defaults where needed
: ${MATCHING_LABEL:=${INPUT_MATCHING_LABEL:="sensu.io/workflow"}}
: ${MATCHING_CONDITION:=${INPUT_MATCHING_CONDITION:="== sensu_flow"}}
: ${MANAGED_RESOURCES:=${INPUT_MANAGED_RESOURCES:="checks,handlers,filters,mutators,assets,secrets/v1.Secret,roles,role-bindings,core/v2.HookConfig"}}
: ${NAMESPACES_DIR:=${INPUT_NAMESPACES_DIR:=".sensu/namespaces"}}
: ${NAMESPACES_FILE:=${INPUT_NAMESPACES_FILE:=".sensu/cluster/namespaces.yaml"}}
: ${DISABLE_SANITY_CHECKS:=${INPUT_DISABLE_SANITY_CHECKS:="false"}}
: ${VERBOSE:=${INPUT_VERBOSE:=""}}
: ${SENSU_USER:=${INPUT_SENSU_USER}}
: ${SENSU_PASSWORD:=${INPUT_SENSU_PASSWORD}}
: ${SENSU_BACKEND_URL:=${INPUT_SENSU_BACKEND_URL}}
: ${CONFIGURE_ARGS:=${INPUT_CONFIGURE_ARGS}}
: ${SENSU_CA_STRING:=${INPUT_SENSU_CA_STRING}}
: ${SENSU_CA_FILE:=${INPUT_SENSU_CA_FILE}}

if [[ $VERBOSE ]]; then echo "Working Directory: $PWD"; fi
# Check for required envvars to be defined
preflight_check=0
[ -z "$SENSU_USER" ] && echo "SENSU_USER environment variable empty" && preflight_check=1
[ -z "$SENSU_PASSWORD" ] && echo "SENSU_PASSWORD environment variable empty" && preflight_check=1
[ -z "$SENSU_BACKEND_URL" ] && echo "SENSU_BACKEND_URL environment variable empty" && preflight_check=1
[ -z "$MATCHING_LABEL" ] && echo "MATCHING_LABEL environment variable empty" && preflight_check=1
[ -z "$MATCHING_CONDITION" ] && echo "MATCHING_CONDITION environment variable empty" && preflight_check=1
[ -z "$MANAGED_RESOURCES" ] && echo "MANAGED_RESOURCES environment variable empty" && preflight_check=1
[ -z "$NAMESPACES_DIR" ]  && echo "NAMESPACES_DIR environment variable empty" && preflight_check=1

if test $preflight_check -ne 0 ; then
	echo "Missing environment variables"
	exit 1
else
	if [[ $VERBOSE ]]; then echo "All needed environment variables are available"; fi
fi

LABEL_SELECTOR="${MATCHING_LABEL} ${MATCHING_CONDITION}"
if [ -z "$SENSU_CA_STRING" ] ; then
	touch /tmp/sensu_ca.pem
else
	echo $SENSU_CA_STRING > /tmp/sensu_ca.pem  
fi
: ${SENSU_CA_FILE:="/tmp/sensu_ca.pem"}	

if [ -s $SENSU_CA_FILE ]; then
        if [[ $VERBOSE ]]; then echo "custom CA file present"; fi
	CA_ARG="--trusted-ca-file ${SENSU_CA_FILE}"
else
 	CA_ARG=''
fi

if [[ $VERBOSE ]]; then echo "Checking Sensu readiness"; fi
status=$(curl --connect-timeout 30 -s -o /dev/null -w "%{http_code}"  "$SENSU_BACKEND_URL/health")
if [ $status -lt 200 ] || [ $status -ge 400 ]; then
	echo "Sensu Backend does not appear to be ready"
	echo "Probe of "$SENSU_BACKEND_URL/health" returned status code: $status"
	exit 1
fi

if [ "$DISABLE_SANITY_CHECKS" = "false" ]; then
	DISABLE_SANITY_CHECKS="" 
fi
if [ -z "$DISABLE_SANITY_CHECKS" ]; then
	if [[ $VERBOSE ]]; then echo "sanity checks enabled"; fi
else
	if [[ $VERBOSE ]]; then echo "sanity checks disabled"; fi
fi


if [[ $VERBOSE ]]; then echo "Configuring sensuctl:"; fi
sensuctl configure -n --username ${SENSU_USER} --password ${SENSU_PASSWORD} --url ${SENSU_BACKEND_URL} ${CA_ARG}  ${CONFIGURE_OPTIONS}
retval=$?
sensuctl config view
if test $retval -ne 0; then
	echo "sensuctl configure failed"
	exit $retval
fi
if [[ $VERBOSE ]]; then
	echo "Current Directory:"
	pwd
	echo "Executing Sensuflow"
	echo "Matching Label: ${MATCHING_LABEL}"
	echo "Matching Condition: ${MATCHING_CONDITION}"
	echo "Label Selector: ${LABEL_SELECTOR}"
fi
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

function lint_resource_metadata {
  resource_dir=$1
  required_label=$2
  allowed_namespace=$3
  if [[ $VERBOSE ]]; then echo "linting resource metadata in $resource_dir"; fi
  yaml_files=$(find $resource_dir -name "*.y?ml")
  for file in $yaml_files; do
   if [[ $required_label ]]; then
      bad_labels=$(yq -N e ".metadata.labels | has(\"${required_label}\")" $file | grep -c 'false' )
      if [ $bad_labels  -ne 0 ] ; then die "resource in $file may be missing label $MATCHING_LABEL" ; fi
      bad_labels=$(yq -N e ".metadata.labels[\"${required_label}\"] == null" $file | grep -c 'true' )
      if [ $bad_labels  -ne 0 ] ; then die "resource in $file may be missing label $MATCHING_LABEL" ; fi
   fi
   result=$(yq -N e '.metadata.namespace' $file)
   for line in $result; do
     if [ $line != "null" ]; then 
       if [[ $allowed_namespace ]]; then	    
         if [ $line != $allowed_namespace ]; then die "resource in $file has metadata.namespace defined as $line" ; fi
       else
         if [[ $line ]]; then die "resource in $file has metadata.namespace defined as $line" ; fi
       fi
     fi
   done	
  done	  
  json_files=$(find $resource_dir -name "*.json")
  for file in $json_files ; do
   if [[ $required_label ]]; then
      bad_labels=$(jq ".metadata.labels[\"${required_label}\"] == null" $file | grep -c 'true')
      if [ $bad_labels  -ne 0 ] ; then die "resource in $file may be missing label $MATCHING_LABEL" ; fi
   fi
   result=$(jq '.metadata.namespace' $file)
   for line in $result; do
     if [ $line != 'null' ]; then
       if [[ $allowed_namespace ]]; then	    
         if [ $line != \"$allowed_namespace\" ]; then die "Error resource in $file has metadata.namespace defined as $line instead of \"$allowed_namespace\"" ; fi
       else
         if [[ $line ]]; then die "resource in $file has metadata.namespace defined as $line" ; fi
       fi
     fi
   done	
  done	  

}

# Main

# First, make sure we have our namespaces
if test -f ${NAMESPACES_FILE}
then
	yq -N e '.' ${NAMESPACES_FILE}  > /dev/null || die "$NAMESPACES_FILE is not valid yaml"

	sensuctl create -f ${NAMESPACES_FILE} || die "sensuctl error creating namespaces file"
        	
fi


cd $NAMESPACES_DIR || die "Failed to cd to namespaces directory!"
if [[ $VERBOSE ]]; then echo "Namespaces Directory: $(pwd)"; fi

for namespace in $(ls -1)
do
  # If not a directory of resources then skip
  if ! test -d ${namespace}
  then
     echo "${namespace} in ${NAMESPACES_DIR}/ is not a directory, skipping"
     continue
  fi
  if [ -z $DISABLE_SANITY_CHECKS ]; then lint_resource_metadata ${namespace} ${MATCHING_LABEL} ${namespace}; fi

  if ! is_namespace ${namespace}
  then
     # Skip or die?
     # Skip means this may pass silently, die would cause bad exit
     # that should cause a build failure
     echo "Directory ${namespace} exists in namespaces/ but is not a defined namespace in sensu, skipping"
     continue
  fi


  echo "Namespace ${namespace}"
  echo -e "Pruning resources...\n"
  if [[ $VERBOSE ]] 
  then 
	  echo -e "sensuctl prune ${MANAGED_RESOURCES} --namespace ${namespace} --label-selector \"${LABEL_SELECTOR}\" -r -f ${namespace} | jq '. | length'"
  fi

  num=$(sensuctl prune ${MANAGED_RESOURCES} --namespace ${namespace} --label-selector "${LABEL_SELECTOR}" -r -f ${namespace} | jq '. | length')
  retval=$?
  if test $retval -ne 0; then 
	echo "Error during sensuctl prune!"
	exit 1
  fi
  echo "${num} resources deleted"

  echo -e "Creating/Updating resources...\c"
  # Would be really nice if this gave us some type of output
  sensuctl create -r -f ${namespace} --namespace ${namespace}
  retval=$?
  if test $retval -ne 0; then 
	echo "Error during sensuctl create!"
	exit 1
  fi
  echo -e "Done\n"

done


