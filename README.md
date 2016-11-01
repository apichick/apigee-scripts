# Installation

* Clone git repository to a local directory

        $ git clone https://bitbucket.org/mesnaola/apigee-scripts.git

* Install dependencies listed below

* Add the directory where the scripts are to the PATH environment variable.


# Dependencies

## Mac OSX

    $ brew install jq node
    $ npm -g install jshint cucumber mocha // Required only for the proxy deployment script

### Ubuntu

    $ sudo apt-get install curl jq nodejs npm
    $ npm -g install jshint cucumber mocha // Required only for the proxy deployment script

# Configuring your profile

Create a file named .apigeerc in your HOME directory and enter your Apigee Credentials (USERNAME and PASSWORD).

In addition, you can add another variable named DEPLOYMENT_SUFFIX to ~/.apigeerc. As we will see later on, the value of that variable will be relevant when working on development mode.

# Running the scripts

## Resource operations

    $ edge-cli -u <USERNAME> -p <PASSWORD> -o <ORGANIZATION> -e <ENVIRONMENT> -r <RESOURCE> -a <ACTION>

This command will run a certain operation over a resource in an organization's environment.

Options:

- u: Apigee username (optional, it can be read from ~/.apigeerc)
- p: Apigee password (optional, it can be read from ~/.apigeerc)
- o: Organization (optional, by default the name of the default organization created by Apigee Edge for when you register, that matches the local part of the email address provided as username)
- e: Environment (optional, by default test)
- r: Resource, possible values are cache|keyvaluemap|vault|virtualhost|targetserver
- a: Action, value depends on the resource selected

    * api: delete|fetch|list|undeploy
    * apiproduct: create|delete|fetch|list
    * developerapp: create|delete|fetch|list
    * cache: clear_entry|clear_entries|create|delete|fetch|list
    * company: create|delete|list
    * companyapp: list
    * keyvaluemap: create|create_entry|delete|delete_entry|fetch|list
    * vault: create|create_entry|delete|delete_entry|fetch|list
    * virtualhost: create|delete|fetch|list
    * targetserver: create|delete|fetch|list
    * keystore: create|delete|fetch|list
    * developer: create|delete|fetch|list
    * resource: fetch|lis
    * environment: fetch|list
    * deployment: list

## Environment export/import

### Export

    $ edge-dump-env -u <USERNAME> -p <PASSWORD> -o <ORGANIZATION> -e <ENVIRONMENT> > > file.json

This command creates a JSON output with the current configuration in an specific environment. Find below and example of how this file would look like.

        {
          "cache": [
            {
              "description": "",
              "diskSizeInMB": 0,
              "distributed": true,
              "expirySettings": {
                "timeoutInSec": {
                  "value": "604800"
                },
                "valuesNull": false
              },
              "inMemorySizeInKB": 0,
              "maxElementsInMemory": 0,
              "maxElementsOnDisk": 0,
              "name": "test_cache",
              "overflowToDisk": false,
              "persistent": false
            }
          ],
          "keyvaluemap": [
            {
              "entry": [
                {
                  "name": "key_1",
                  "value": "value_1"
              },
                {
                  "name": "key_2",
                  "value": "value_2"
                }
              ],
              "name": "test_kvm"
            }
          ],
          "vault": [
            {
              "entries": [
                {
                  "name": "password",
                  "value": "*****"
                },
                {
                  "name": "username",
                  "value": "*****"
                }
              ],
              "name": "test_vault"
            }
          ],
          "virtualhost": [
            {
              "hostAliases": [
                "org-domain.com"
              ],
              "interfaces": [],
              "name": "default",
              "port": "80"
            }
          ]
        }

Options:

- u: Apigee username (optional, it can be read from ~/.apigeerc)
- p: Apigee password (optional, it can be read from ~/.apigeerc)
- o: Organization (optional, by default the name of the default organization created by Apigee Edge for when you register, that matches the local part of the email address provided as username)
- e: Environment (optional, by default test)

### Import

    $ edge-import-env -u <USERNAME> -p <PASSWORD> -o <ORGANIZATION> -e <ENVIRONMENT> < file.json

This command imports the environment configuration (caches, keyvaluemaps, vaults, virtualhosts) from a file. The file should have the same format as the one you get from the dump.

Options:

- u: Apigee username (optional, it can be read from ~/.apigeerc)
- p: Apigee password (optional, it can be read from ~/.apigeerc)
- o: Organization (optional, by default the name of the default organization created by Apigee Edge for when you register, that matches the local part of the email address provided as username)
- e: Environment (optional, by default test)

## Documentation

    $ edge-doc <POLICY_NAME>

This script opens the documentation of a policy in your default browser

The policy name is optional. If none is provided and list of the available policies is displayed, and you can enter your choice.

## Deployment

    $ edge-deploy -u <USERNAME> -p <PASSWORD> -o <ORGANIZATION> -e <ENVIRONMENT> -a <ACTION> -n <PROXY_NAME> -b <PROXY_BASEPATH> <PATH>

This command let's you deploy a proxy for a specific organization and environment and runs the unit and integration tests.

Options:

- u: Apigee username (optional, it can be read from ~/.apigeerc)
- p: Apigee password (optional, it can be read from ~/.apigeerc)
- o: Organization (optional, by default the name of the default organization created by Apigee Edge for when you register, that matches the local part of the email address provided as username)
- e: Environment (optional, by default test)
- a: Action, possible value are update|override, the behavior is similar to the maven plugin (optional, by default override)
- l: Flag, that if present, indicates that we are NOT working in development mode. We say that we are working in development mode when several developers are actually deploying and trying out the same proxy in the same environment.
- n: Name of the proxy (optional, by default it will be the name of the directory where the proxy files are located. If we are working in development mode and the DEPLOYMENT_SUFFIX variable has been set, its value will be appended to the actual name provided. If it has not been set, it will append a dash followed by the local part of the email address provided as username)
- t: Flag, that if present, indicates that only tests should run and no deployment is required

An argument needs to be provided, that is the path where the proxy to be deployed is located in your filesystem.

You can use tokens to be replaced in the files available inside the apiproxy and test directories. The syntax used for the tokens will be ${}. The values for this tokens will be set in a file named settings\_\[ENVIRONMENT\].conf. There are a set of default tokens that can be used without needing to set them in settings\_\[ENVIRONMENT\].conf:

- apigee.username
- apigee.password
- apigee.organization
- apigee.environment
- apigee.hosturl
- apigee.apiversion
- apiproxy.deploymentSuffix (It can appended to the base path in the ProxyEndpoint, to avoid clashes when more than one person is using the same environment for deployments)

##BaaS

    $ baas-cli -o <ORGANIZATION> -u <CLIENT_ID> -p <CLIENT_SECRET> -r <RESOURCE> -a <ACTION>

This command will run a certain operation over a resource in a BaaS organization.

Options:

- o: BaaS organization (optional, by default the name of the default organization created when you register, that matches the local part of the email address provided as username)
- u: The client id of the BaaS organization (optional, it can be read from ~/.apigeerc)
- p: The client secret of the BaaS organization (optional, it can be read from ~/.apigeerc)
- r: Resource, possible values are app|collection|entity
- a: Action, value depends on the resource selected

    * app: create|get_credentials|list
    * collection: create|list
    * entity: list
