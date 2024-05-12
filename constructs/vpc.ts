import { Construct } from "constructs";
import { Fn } from "cdktf";
import { Vpc } from "@cdktf/provider-aws/lib/vpc";
import { Subnet } from "@cdktf/provider-aws/lib/subnet";
import { InternetGateway } from "@cdktf/provider-aws/lib/internet-gateway";
import { RouteTable } from "@cdktf/provider-aws/lib/route-table";
import { Route } from "@cdktf/provider-aws/lib/route";
import { RouteTableAssociation } from "@cdktf/provider-aws/lib/route-table-association";
import { VpcEndpoint } from "@cdktf/provider-aws/lib/vpc-endpoint";

export class VPC extends Construct {
  public readonly id: string;
  public readonly subnets: Subnet[] = [];

  constructor(scope: Construct, id: string) {
    super(scope, id);

    const vpc = new Vpc(this, "vpc", {
      cidrBlock: "10.0.0.0/24",
      assignGeneratedIpv6CidrBlock: true,
      enableDnsHostnames: true,
      tags: {
        Name: "minube",
      },
    });
    this.id = vpc.id;

    const internetGateway = new InternetGateway(this, "igw", {
      vpcId: this.id,
      tags: {
        Name: "minube",
      },
    });

    const routeTable = new RouteTable(this, "routeTable", {
      vpcId: this.id,
      tags: {
        Name: "minube",
      },
    });

    new Route(this, "route4", {
      routeTableId: routeTable.id,
      destinationCidrBlock: "0.0.0.0/0",
      gatewayId: internetGateway.id,
    });

    new Route(this, "route6", {
      routeTableId: routeTable.id,
      destinationIpv6CidrBlock: "::/0",
      gatewayId: internetGateway.id,
    });

    this.subnets.push(
      new Subnet(this, "subnet", {
        vpcId: this.id,
        cidrBlock: Fn.cidrsubnet(vpc.cidrBlock, 2, 0),
        ipv6CidrBlock: Fn.cidrsubnet(vpc.ipv6CidrBlock, 8, 0),
        mapPublicIpOnLaunch: true,
        assignIpv6AddressOnCreation: true,
        tags: {
          Name: "minube",
        },
      })
    );

    new RouteTableAssociation(this, "routeTableAssociation", {
      routeTableId: routeTable.id,
      subnetId: this.subnets[0].id,
    });

    new VpcEndpoint(this, "s3Endpoint", {
      vpcId: this.id,
      serviceName: "com.amazonaws.eu-central-1.s3",
      routeTableIds: [routeTable.id],
      tags: {
        Name: "minube-s3-endpoint",
      },
    });
  }
}
