#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { MinubeStack } from "../lib/minube-stack";

const app = new cdk.App();
new MinubeStack(app, "MinubeStack", {});
