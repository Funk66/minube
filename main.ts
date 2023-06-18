import { Construct } from "constructs";
import { readFileSync } from "fs";
import { App, TerraformStack, CloudBackend, NamedCloudWorkspace } from "cdktf";
import { AwsProvider } from "@cdktf/provider-aws/lib/provider";
import { DataAwsSsmParameter } from "@cdktf/provider-aws/lib/data-aws-ssm-parameter";
import { Vpc } from "@cdktf/provider-aws/lib/vpc";
import { Subnet } from "@cdktf/provider-aws/lib/subnet";
import { SecurityGroup } from "@cdktf/provider-aws/lib/security-group";
import { KeyPair } from "@cdktf/provider-aws/lib/key-pair";
import { Instance } from "@cdktf/provider-aws/lib/instance";
import { InternetGateway } from "@cdktf/provider-aws/lib/internet-gateway";
import { RouteTable } from "@cdktf/provider-aws/lib/route-table";
import { Route } from "@cdktf/provider-aws/lib/route";
import { RouteTableAssociation } from "@cdktf/provider-aws/lib/route-table-association";

class Stack extends TerraformStack {
  constructor(scope: Construct, id: string) {
    super(scope, id);
    new AwsProvider(this, "aws", { region: "eu-central-1" });

    const ami = new DataAwsSsmParameter(this, "ubuntu", {
      name: "/aws/service/canonical/ubuntu/server/22.04/stable/current/arm64/hvm/ebs-gp2/ami-id",
    }).value;

    const vpc = new Vpc(this, "vpc", {
      cidrBlock: "10.0.0.0/16",
      enableDnsHostnames: true,
      tags: {
        Name: "minube",
      },
    });

    const internetGateway = new InternetGateway(this, "igw", {
      vpcId: vpc.id,
      tags: {
        Name: "minube",
      },
    });

    const routeTable = new RouteTable(this, "routeTable", {
      vpcId: vpc.id,
      tags: {
        Name: "minube",
      },
    });

    new Route(this, "route", {
      routeTableId: routeTable.id,
      destinationCidrBlock: "0.0.0.0/0",
      gatewayId: internetGateway.id,
    });

    const subnet = new Subnet(this, "subnet", {
      vpcId: vpc.id,
      cidrBlock: "10.0.0.0/24",
      mapPublicIpOnLaunch: true,
      tags: {
        Name: "minube",
      },
    });

    new RouteTableAssociation(this, "routeTableAssociation", {
      routeTableId: routeTable.id,
      subnetId: subnet.id,
    });

    const sg = new SecurityGroup(this, "sg", {
      name: "minube",
      vpcId: vpc.id,
      egress: [
        {
          fromPort: 0,
          toPort: 0,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "-1",
        },
      ],
      ingress: [
        {
          fromPort: 22,
          toPort: 22,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "TCP",
        },
        {
          fromPort: 51820,
          toPort: 51820,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "UDP",
        },
      ],
    });

    const key = new KeyPair(this, "key", {
      keyName: "ggaguilar",
      publicKey: readFileSync("./assets/key.pub", "utf8"),
    });

    new Instance(this, "ec2", {
      ami: ami,
      instanceType: "t4g.micro",
      securityGroups: [sg.id],
      subnetId: subnet.id,
      keyName: key.id,
      userData: readFileSync("./assets/userdata.sh", "utf8"),
      tags: {
        Name: "minube",
      },
    });
  }
}

const app = new App();
const stack = new Stack(app, "minube");
new CloudBackend(stack, {
  hostname: "app.terraform.io",
  organization: "minube",
  workspaces: new NamedCloudWorkspace("minube"),
});
app.synth();
