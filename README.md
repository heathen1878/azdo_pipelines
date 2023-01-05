# Azure DevOps pipeline examples

A collection of Azure DevOps pipelines
## Docker Build

Example usage
```yaml
...
steps:
    - template: docker_build/docker_build.yml
      parameters:
        acr: $(container_registry)
        dockerfile_path: $(dockerfile_path)
        image_repository: $(image_repository)
        service_connection: $(service_connection)
        tags: $(tags)
...
```
