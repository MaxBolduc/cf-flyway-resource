# cf-flyway-resource

Version control for your database so you can migrate it with ease and confidence to Cloud Foundry database services with concourse-ci.

Features:

* Seamless connection to CF database services.
* Support all flyway cli commands. (Community Edition)
* Support flyway configuration file.
* Output database service metadata.

## resource_types

The image _cf-flyway-resource_ is built from [boxfuse/flyway](https://hub.docker.com/r/boxfuse/flyway). It also comes with the `cf_cli` and `jq` installed.


```yml
- name: cf-flyway-resource
  type: docker-image
  source:
    repository: emeraldsquad/cf-flyway-resource
    tag: 0.1.0
```

For a list of available tags, consult our [Docker Hub repo](https://hub.docker.com/r/jpmorin/cf-flyway-resource/tags).

## resource

### source

* **api** : _required_ the api endpoint of the Cloud Foundry Cloud Controller
* **username**: _required_ username to authenticate
* **password**: _required_ password to authenticate
* **organization** : _required_ the name of the organization to push to
* **space** : _required_ the name of the space to push to
* **service** : _required_ the name of the database service instance to push to

```yml
- name: cf-flyway
  type: cf-flyway-resource
  source:
    api: cf-api-endpoint
    username: cf-user
    password: cf-user-password
    organization: organization-name
    space: space-name
    service: service-instance-name
```

## check

The **check** script always returns the current version number, or generate an initial version if none was received.

## in

Read service information from the cf api to produce metadata.

```yml
metadata_url : /v2/service_instances/fe7f0258-5b6f-7b26-2cb2-79ad6f2a7454
pcf_api : https://my.api.endpoint.com
pcf_org : organization-name
pcf_space : space-name
service_instance : service-instance-name
service_label : a9s-postgresql94
service_plan : postgresql-single-small
```

The **in** script always returns the current version number. Therefore, the resources cannot be used as an input trigger.

## out

Migrate database schemas to CloudFoundry database service.

The **out** script creates a service-key on the CloudFoundry database service. It then read the credentials of the service-key and generate a `flyway.config` file containing the CloudFoundry database service-key jdbcUrl, username and password. The generated `flyway.config` file will also have `flyway.cleanDisabled=true` set by default. Any other flyway configuration provided by the user is also appended to the generated `flyway.conf` file.

The **out** script then execute the commands reveived as parameters. If no command parameters are set, the script defaults to the following commands.

* `flyway info`
* `flyway migrate`
* `flyway info`


### params

* __locations__ _required_
  * Comma-separated list of locations to scan recursively for migrations.
  * The location type is determined by its prefix.
  * Unprefixed locations or locations starting with `classpath:` point to a package on the classpath and may contain both SQL and Java-based migrations.
  * Locations starting with `filesystem:` point to a directory on the filesystem, may only contain SQL migrations and are only scanned recursively down non-hidden directories.
* __commands__ _optional_
  * List of commands to execute.
  * Available commands are:
    * migrate  : Migrates the database
    * clean    : Drops all objects in the configured schemas
    * info     : Prints the information about applied, current and pending migrations
    * validate : Validates the applied migrations against the ones on the classpath
    * undo     : [pro] Undoes the most recently applied versioned migration
    * baseline : Baselines an existing database at the baselineVersion
    * repair   : Repairs the schema history table
* __flyway_conf__ _optional_
  * one of:
    * path to an existing flyway.conf file.
    * inline flyway configuration.
  * Please note that the following configuration will be overwritten by information from the CloudFoundry service-key.
    * `flyway.url`
    * `flyway.user`
    * `flyway.password`

#### Exemples

1. Only use the required locations parameter.

```yml
jobs:
- name: deploy
  plan:
  - get: my-app-package
  - put: cf-flyway
    params:
      locations: filesystem:my-app-package/DB/Schema
```

2. Add a flyway configuration file.

```yml
jobs:
- name: deploy
  plan:
  - get: my-app-package
  - put: cf-flyway
    params:
      locations: filesystem:my-app-package/DB/Schema
      flyway_conf: my-app-package/DB/flyway.config
```

3. Add inline flyway configuration.

```yml
jobs:
- name: deploy
  plan:
  - get: my-app-package
  - put: cf-flyway
    params:
      locations: filesystem:my-app-package/DB/Schema
      flyway_conf: |-
        flyway.schemas=dbo
        flyway.licenseKey=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

4. Use a command sequence.

```yml
jobs:
- name: deploy
  plan:
  - get: my-app-package
  - put: cf-flyway
    params:
      locations: filesystem:my-app-package/DB/Schema
      commands: [info, undo --pro, info] # optional, default to [info, migrate, info]
      flyway_conf: |-
        flyway.schemas=dbo
        flyway.licenseKey=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```