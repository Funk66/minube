import { Construct } from "constructs";
import { Vpc } from "@cdktf/provider-aws/lib/vpc";
import { Subnet } from "@cdktf/provider-aws/lib/subnet";
import { InternetGateway } from "@cdktf/provider-aws/lib/internet-gateway";
import { RouteTable } from "@cdktf/provider-aws/lib/route-table";
import { Route } from "@cdktf/provider-aws/lib/route";
import { RouteTableAssociation } from "@cdktf/provider-aws/lib/route-table-association";


export class VPC extends Construct {
  public readonly id: string;
  public readonly subnets: Subnet[] = [];

  constructor(scope: Construct, id: string) {
    super(scope, id);

    this.id = new Vpc(this, "vpc", {
      cidrBlock: "10.0.0.0/24",
      enableDnsHostnames: true,
      tags: {
        Name: "minube",
      },
    }).id;

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

    new Route(this, "route", {
      routeTableId: routeTable.id,
      destinationCidrBlock: "0.0.0.0/0",
      gatewayId: internetGateway.id,
    });

    this.subnets.push(
      new Subnet(this, "subnet", {
        vpcId: this.id,
        cidrBlock: "10.0.0.0/24",
        mapPublicIpOnLaunch: true,
        tags: {
          Name: "minube",
        },
      })
    );

    new RouteTableAssociation(this, "routeTableAssociation", {
      routeTableId: routeTable.id,
      subnetId: this.subnets[0].id,
    });
  }
}
