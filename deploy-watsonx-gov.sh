#!/bin/bash

###
# Confirm jq is installed
if [[ ! $(which jq 2> /dev/null ) ]]; then
    echo "ERROR: jq tool not found"
    exit 1
fi

###
# Parse parameter file
PARAMETERS="$1"

export BIN_DIR="$(cat $PARAMETERS | jq -r .directories.bin_dir)"
export CPD_WORKSPACE="$(cat $PARAMETERS | jq -r .directories.cpd_dir)"
export API_SERVER="$(cat $PARAMETERS | jq -r .cluster.api_server)"
export OCP_USERNAME="$(cat $PARAMETERS | jq -r .cluster.username)"
export OCP_PASSWORD="$(cat $PARAMETERS | jq -r .cluster.password)"
export STG_CLASS_FILE="$(cat $PARAMETERS | jq -r .cluster.storageclass.file)"
export STG_CLASS_BLOCK="$(cat $PARAMETERS | jq -r .cluster.storageclass.block)"
export OPERATOR_NAMESPACE="$(cat $PARAMETERS | jq -r .cpd.namespace.cpd_operator)"
export INSTANCE_NAMESPACE="$(cat $PARAMETERS | jq -r .cpd.namespace.cpd_operands)"
export VERSION="$(cat $PARAMETERS | jq -r .cpd.version)"

export INSTALL_TYPE="$(cat $PARAMETERS | jq -r .watsonxgov.install_type)"
export FACTSHEET="$(cat $PARAMETERS | jq -r .watsonxgov.factsheet)"
export OPENSCALE="$(cat $PARAMETERS | jq -r .watsonxgov.openscale)"
export OPENPAGES_INSTALL="$(cat $PARAMETERS | jq -r .watsonxgov.openpages.enable)"
export OPENPAGES_EXISTING="$(cat $PARAMETERS | jq -r .watsonxgov.openpages.existing.existing_instance)"
export OPENPAGES_NAMESPACE="$(cat $PARAMETERS | jq -r .watsonxgov.openpages.existing.namespace)"
export OPENPAGES_GLOBALSEARCH="$(cat $PARAMETERS | jq -r .watsonxgov.openpages.global_search)"
export OPENPAGES_DBTYPE="$(cat $PARAMETERS | jq -r .watsonxgov.openpages.existing.db_type)"
export OPENPAGES_DB="$(cat $PARAMETERS | jq -r .watsonxgov.openpages.existing.db)"
export OPENPAGES_DBSECRET="$(cat $PARAMETERS | jq -r .watsonxgov.openpages.existing.db_secret)"

###
# Confirm oc cli and log into the OpenShift cluster
if [[ ! -f ${BIN_DIR}/oc ]]; then
    echo "ERROR: oc tool not installed at ${BIN_DIR}/oc"
    exit 1
else
    if [[ ! $(${BIN_DIR}/oc status 2> /dev/null) ]]; then
        echo "**** Trying to log into the OpenShift cluster from command line"
        ${BIN_DIR}/oc login "${API_SERVER}" -u $OCP_USERNAME -p $OCP_PASSWORD --insecure-skip-tls-verify=true

        if [[ $? != 0 ]]; then
            echo "ERROR: Unable to log into OpenShift cluster"
            exit 1
        fi
    else
        echo
        echo "**** Already logged into the OpenShift cluster"
    fi
fi

###
# Confirm storage cluster in place 
# if [[ ! $(${BIN_DIR}/oc get storagecluster -A | grep -v NAMESPACE) ]]; then
#     echo "ERROR: No storage cluster found"
#     exit 1
# fi

###
# Confirm cpd-cli is installed and login to OpenShift with cpd-cli
if [[ ! -f ${BIN_DIR}/cpd-cli ]]; then
    echo "ERROR: cpd-cli not installed at ${BIN_DIR}/cpd-cli"
    exit 0
else
    ${BIN_DIR}/cpd-cli manage login-to-ocp --server "${API_SERVER}" -u $OCP_USERNAME -p $OCP_PASSWORD

    if [[ $? != 0 ]]; then
        echo "ERROR: Failed to log into the OpenShift cluster via the cpd cli tool"
        exit 1
    fi
fi

###
# Create watsonx.governance catalog source and operator subscription
echo
echo "**** Creating watsonx.governance catalog source and operator subscription"
${BIN_DIR}/cpd-cli manage apply-olm --release=${VERSION} --components=watsonx_governance --cpd_operator_ns=${OPERATOR_NAMESPACE}

if [[ $? != 0 ]]; then
    echo "ERROR: Failed to apply watsonx.governance catalog or subscription"
    exit 1
fi

###
# Create the custom spec file
if [[ ${OPENPAGES_EXISTING} == "true" ]]; then
    cat << EOF >> ${CPD_WORKSPACE}/olm-utils-workspace/work/install-options.yaml
custom_spec:
  watsonx_governance:
    installType: ${INSTALL_TYPE}
    enableFactsheet: ${FACTSHEET}
    enableOpenscale: ${OPENSCALE}
    enableOpenpages: ${OPENPAGES_INSTALL}
    openpagesInstanceCR: ${OPENPAGES_NAMESPACE}
    openPages:
        database: ${OPENPAGES_DB}
        enableGlobalSearch: ${OPENPAGES_GLOBALSEARCH}   
        databaseType: ${OPENPAGES_DBTYPE} 
        dbSecretName: ${OPENPAGES_DBSECRET}
EOF
else
    cat << EOF >> ${CPD_WORKSPACE}/olm-utils-workspace/work/install-options.yaml
custom_spec:
  watsonx_governance:
    installType: ${INSTALL_TYPE}
    enableFactsheet: ${FACTSHEET}
    enableOpenscale: ${OPENSCALE}
    enableOpenpages: ${OPENPAGES_INSTALL}
    openPages:
        database: ${OPENPAGES_DB}
        enableGlobalSearch: ${OPENPAGES_GLOBALSEARCH}   
EOF
fi

###
# Create the watsonx.governance operand
${BIN_DIR}/cpd-cli manage apply-cr --release=${VERSION} --components=watsonx_governance  --license_acceptance=true --cpd_operator_ns=${OPERATOR_NAMESPACE} --cpd_instance_ns=${INSTANCE_NAMESPACE} --file_storage_class=${STG_CLASS_FILE} --block_storage_class=${STG_CLASS_BLOCK} --param-file=/tmp/work/install-options.yaml

if [[ $? != 0 ]]; then
    echo "ERROR: Failed to create watsonx.governance operands"
    exit 1
fi