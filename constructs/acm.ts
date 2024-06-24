import { Construct } from "constructs";
import { AwsProvider } from "@cdktf/provider-aws/lib/provider";
import { AcmCertificate } from "@cdktf/provider-aws/lib/acm-certificate";
// import { AcmCertificateValidation } from "@cdktf/provider-aws/lib/acm-certificate-validation";

export class ACM extends Construct {
  certificate: AcmCertificate;
  // validation: AcmCertificateValidation;

  constructor(scope: Construct, name: string, provider: AwsProvider) {
    super(scope, name);
    this.certificate = new AcmCertificate(this, "cert", {
      provider: provider,
      domainName: "guirao.net",
      subjectAlternativeNames: ["*.guirao.net"],
      validationMethod: "DNS",
    });
    // this.validation = new AcmCertificateValidation(this, "cert-validation", {
    //   certificateArn: this.certificate.arn,
    //   validationRecordFqdns: this.certificate.domainValidationOptions.map(
    //     (option) => option.resourceRecordName
    //   ),
    // });
  }
}
