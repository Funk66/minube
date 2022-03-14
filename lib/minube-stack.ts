import { Stack, StackProps } from "aws-cdk-lib";
import * as path from "path";
import { Construct } from "constructs";
import { Asset } from "aws-cdk-lib/aws-s3-assets";
import { Role, ServicePrincipal, ManagedPolicy } from "aws-cdk-lib/aws-iam";
import {
  AmazonLinuxCpuType,
  AmazonLinuxGeneration,
  AmazonLinuxImage,
  Instance,
  CfnEIP,
  InstanceClass,
  InstanceSize,
  InstanceType,
  CfnEIPAssociation,
  Peer,
  Port,
  SecurityGroup,
  SubnetType,
  Vpc,
} from "aws-cdk-lib/aws-ec2";

export class MinubeStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const vpc = new Vpc(this, "VPC", {
      natGateways: 0,
      subnetConfiguration: [
        {
          cidrMask: 24,
          name: "asterisk",
          subnetType: SubnetType.PUBLIC,
        },
      ],
    });

    const securityGroup = new SecurityGroup(this, "SecurityGroup", {
      vpc,
      description: "Deny all",
      allowAllOutbound: true,
    });
    securityGroup.addIngressRule(
      Peer.anyIpv4(),
      Port.udp(51280),
      "Allow WireGuard Access"
    );

    const role = new Role(this, "ec2Role", {
      assumedBy: new ServicePrincipal("ec2.amazonaws.com"),
    });

    role.addManagedPolicy(
      ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore")
    );

    const ami = new AmazonLinuxImage({
      generation: AmazonLinuxGeneration.AMAZON_LINUX_2,
      cpuType: AmazonLinuxCpuType.X86_64,
    });

    const ec2Instance = new Instance(this, "Instance", {
      vpc,
      instanceType: InstanceType.of(InstanceClass.T3, InstanceSize.MICRO),
      machineImage: ami,
      securityGroup: securityGroup,
      role: role,
    });

    const asset = new Asset(this, "Asset", {
      path: path.join(__dirname, "../src/config.sh"),
    });
    const localPath = ec2Instance.userData.addS3DownloadCommand({
      bucket: asset.bucket,
      bucketKey: asset.s3ObjectKey,
    });

    ec2Instance.userData.addExecuteFileCommand({
      filePath: localPath,
      arguments: "--verbose -y",
    });
    asset.grantRead(ec2Instance.role);

    const eip = new CfnEIP(this, "Ip");

    new CfnEIPAssociation(this, "Ec2Association", {
      eip: eip.ref,
      instanceId: ec2Instance.instanceId,
    });
  }
}
