# Deploy watsonx components on an existing cluster

## Prequisites

- An existing OpenShift 4.x cluster 
- IBM Fusion / ODF installed on cluster (you can use the fusion scripts in this repo if needed)
- CLI tools installed
    - podman
    - jq
- passwordless sudo if running as non-root

> Note that these scripts are designed to be run on a Linux distribution

## Preparation

If you have `yq` copy the `parameters.yaml` file to another filename and edit it with the relevant parameters. Once finished with editing, create the JSON version of the file with the following command (change `parameters.yaml` to the filename you copied the original file to),
```shell
cat parameters.yaml | yq -ojson > parameters.json
```

If you do not have `yq` installed, copy the `parameters-template.json` file to another filename and edit. 

> In both cases be sure to add the existing cluster API and credentials in addition to your IBM entitlement key and the home directory for the user (the cpd directory).

## Execution

Once the parameters file is created, run the `build-watsonx.sh` script as follows.
```shell
./build-watsonx.sh parameters.json
```

## References

- [CPD-CLI](https://github.com/IBM/cpd-cli)