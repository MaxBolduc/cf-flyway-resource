# cf-flyway-resource

Version control for your database so you can migrate it with ease and confidence to Cloud Foundry database services with [concourse-ci](https://concourse-ci.org/) and [Flyway](https://flywaydb.org/).

Features:

* Seamless connection to Cloud Foundry database services.
* Support all flyway cli commands.
* Support flyway configuration file.
* Support Community and Pro Edition
* Output database service metadata.

## Supported Tags

The following tags are officially supported:

[![emeraldsquad/cf-flyway-resource](http://dockeri.co/image/emeraldsquad/cf-flyway-resource)](https://hub.docker.com/r/emeraldsquad/cf-flyway-resource/)

* [`1.0.0`, (_Dockerfile_)](https://github.com/emerald-squad/cf-flyway-resource/blob/v1.0.0/Dockerfile)

[![jpmorin/cf-flyway-resource](http://dockeri.co/image/jpmorin/cf-flyway-resource)](https://hub.docker.com/r/jpmorin/cf-flyway-resource/)

* [`0.1.2`, (_Dockerfile_)](https://github.com/emerald-squad/cf-flyway-resource/blob/v0.1.2/Dockerfile)
* [`0.1.1`, (_Dockerfile_)](https://github.com/emerald-squad/cf-flyway-resource/blob/v0.1.1/Dockerfile)

## resource_types

The image _cf-flyway-resource_ is built from [boxfuse/flyway](https://hub.docker.com/r/boxfuse/flyway). It also comes with the `cf_cli` and `jq` installed.

```yml
- name: cf-flyway-resource
  type: docker-image
  source:
    repository: emeraldsquad/cf-flyway-resource
    tag: 1.0.0
```

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

### version

The **check** script always returns the current version number, or generate an initial version if none was received.

Version is expressed as datetime (utc).

## in

### version

The **in** script always returns the current version number. Therefore, the resources cannot be used as an input trigger.

### metadata

Read service information from the cf api to produce metadata.

```yml
metadata_url : /v2/service_instances/fe7f0258-5b6f-7b26-2cb2-79ad6f2a7454
pcf_api : https://my.api.endpoint.com
pcf_org : organization-name
pcf_space : space-name
service_instance : service-instance-name
service_label : pcf-db-service-name
service_plan : pcf-db-service-plan
```

## out

Migrate database schemas to CloudFoundry database service.

The **out** script creates a service-key on the Cloud Foundry database service. It then reads the credentials of the service-key and generate a `flyway.conf` file containing the CloudFoundry database service-key url, username and password.

The generated `flyway.conf` file will also have `flyway.cleanDisabled=true` set by default.

Any other flyway configuration provided by the user is also appended to the generated `flyway.conf` file. Note that the **out** script will always override the following config:

```conf
flyway.url={service-key jdbc:driver//url/database}  # Overwritten by Cloud Foundry service-key credentials
flyway.user={service-key username}                  # Overwritten by Cloud Foundry service-key credentials
flyway.password={service-key password}              # Overwritten by Cloud Foundry service-key credentials
flyway.locations={params.locations}                 # Overwritten by locations parameter (required)
flyway.cleanDisabled=true                           # Overwritten by clean_disabled parameter (optional, default=true)
```

The **out** script then execute flyway commands. If a command list parameters is set, they will be executed sequentialy. If no command list parameters are set, the script defaults to the following commands.

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
  * List of commands to execute. (default: `[info, migrate, info]`)
  * Available commands are:
    * migrate  : Migrates the database
    * clean    : Drops all objects in the configured schemas
    * info     : Prints the information about applied, current and pending migrations
    * validate : Validates the applied migrations against the ones on the classpath
    * undo     : [pro] Undoes the most recently applied versioned migration
    * baseline : Baselines an existing database at the baselineVersion
    * repair   : Repairs the schema history table
* __clean_disabled__ _optional_
  * Whether to disabled clean. (default: `true`)
  * This is especially useful for production environments where running clean can be quite a career limiting move.
* __delete_service_key__ _optional_
  * Whether to delete the service-key on the Cloud Foundry database service when done. (default: `false`)
  * This is especially useful for on-demand qa environment.
* __flyway_conf__ _optional_
  * one of:
    * path to an existing flyway.conf file.
    * inline flyway configuration.
  * The following configuration will be overwritten by the **out** script
    * `flyway.url`
    * `flyway.user`
    * `flyway.password`
    * `flyway.locations`
    * `flyway.cleanDisabled`

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
      flyway_conf: |
        flyway.schemas=dbo
        flyway.connectRetries=2
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
      commands: [info, validate]
```

5. Use Flyway **Pro** feature.

```yml
jobs:
- name: deploy
  plan:
  - get: my-app-package
  - put: cf-flyway
    params:
      locations: filesystem:my-app-package/DB/Schema
      commands: [info, undo, info]
      flyway_conf: |
        flyway.licenseKey=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### version

The **out** script always returns a new version number.

### metadata

Read service information from the cf api to produce metadata.

```yml
metadata_url : /v2/service_instances/fe7f0258-5b6f-7b26-2cb2-79ad6f2a7454
pcf_api : https://my.api.endpoint.com
pcf_org : organization-name
pcf_space : space-name
service_instance : service-instance-name
service_label : pcf-db-service-name
service_plan : pcf-db-service-plan
```
