import { Construct } from "constructs";
import { Fn } from "cdktf";
import { AwsProvider } from "@cdktf/provider-aws/lib/provider";
import { DockerProvider } from "@cdktf/provider-docker/lib/provider";
import { EcrpublicRepository } from "@cdktf/provider-aws/lib/ecrpublic-repository";
import { Image } from "@cdktf/provider-docker/lib/image";
import { RegistryImage } from "@cdktf/provider-docker/lib/registry-image";
import { DataAwsEcrpublicAuthorizationToken } from "@cdktf/provider-aws/lib/data-aws-ecrpublic-authorization-token";
import * as path from "path";

export class ECR extends Construct {
  constructor(scope: Construct, id: string, provider: AwsProvider) {
    super(scope, id);

    const repo = new EcrpublicRepository(this, "caddy", {
      provider: provider,
      repositoryName: "caddy",
      catalogData: {
        architectures: ["ARM64"],
        operatingSystems: ["Linux"],
      },
    });

    const token = new DataAwsEcrpublicAuthorizationToken(this, "auth", {
      provider: provider,
      dependsOn: [repo],
    });

    const decoded = Fn.base64decode(token.authorizationToken);
    const credentials = Fn.split(":", decoded);
    const username = Fn.element(credentials, 0);
    const password = Fn.element(credentials, 1);

    new DockerProvider(this, "docker", {
      registryAuth: [
        {
          address: "public.ecr.aws",
          username: username,
          password: password,
        },
      ],
    });

    const caddyImage = new Image(this, "caddy-image", {
      name: repo.repositoryUri,
      keepLocally: false,
      platform: "linux/arm64",
      buildAttribute: {
        context: path.resolve(__dirname, "../ecr/caddy"),
        dockerfile: "Containerfile",
      },
    });

    new RegistryImage(this, "caddy-latest", {
      name: caddyImage.name,
    });
  }
}
