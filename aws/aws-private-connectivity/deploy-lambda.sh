#!/bin/bash
set -e

# Configuration
AWS_REGION=$(aws configure get region)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
STACK_NAME="private-connectivity-demo"
S3_BUCKET_NAME="lambda-demo-${AWS_ACCOUNT_ID}-${AWS_REGION}"
CODE_ZIP_NAME="lambda_code.zip"

# Check for deployment mode parameter
DEPLOYMENT_MODE=${1:-PUBLIC}
if [[ "$DEPLOYMENT_MODE" != "PUBLIC" && "$DEPLOYMENT_MODE" != "PRIVATE" ]]; then
  echo "Error: Deployment mode must be either PUBLIC or PRIVATE"
  echo "Usage: $0 [PUBLIC|PRIVATE]"
  exit 1
fi

echo "=== AWS Private Connectivity Demo Deployment ==="
echo "AWS Region: ${AWS_REGION}"
echo "AWS Account: ${AWS_ACCOUNT_ID}"
echo "Deployment Mode: ${DEPLOYMENT_MODE}"

# Step 1: Create S3 bucket if it doesn't exist
if ! aws s3api head-bucket --bucket ${S3_BUCKET_NAME} 2>/dev/null; then
  echo "Creating S3 bucket ${S3_BUCKET_NAME}..."
  if [ "${AWS_REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket ${S3_BUCKET_NAME} --region ${AWS_REGION}
  else
    aws s3api create-bucket --bucket ${S3_BUCKET_NAME} --region ${AWS_REGION} --create-bucket-configuration LocationConstraint=${AWS_REGION}
  fi
  echo "S3 bucket created"
fi

# Step 2: Create Lambda function code
echo "Creating Lambda function code..."
mkdir -p .build

cat > .build/lambda_function.py << 'EOF'
import json
import urllib.request
import os

def handler(event, context):
    """Simple Lambda function to demonstrate connectivity"""
    
    # Get the base URL from the event
    host = event.get('headers', {}).get('Host', '')
    stage = event.get('requestContext', {}).get('stage', 'prod')
    base_url = f"https://{host}/{stage}"
    
    # Get the path from event
    path = event.get('path', '/')
    if path.endswith('/'):
        path = path[:-1]
    
    # Get source IP
    source_ip = "Unknown"
    if 'requestContext' in event and 'identity' in event['requestContext']:
        source_ip = event['requestContext']['identity'].get('sourceIp', 'Unknown')
    elif 'headers' in event and 'X-Forwarded-For' in event['headers']:
        source_ip = event['headers']['X-Forwarded-For'].split(',')[0].strip()
    
    # Get deployment mode
    deployment_mode = os.environ.get('DEPLOYMENT_MODE', 'Unknown')
    
    # Handle different paths
    if path == '' or path == '/' or path == f'/{stage}':
        html = f"""
        <html>
        <head><title>AWS Private Connectivity Demo</title></head>
        <body style="font-family: Arial;">
            <h1>AWS Private Connectivity Demo</h1>
            <p>Your IP address: <strong>{source_ip}</strong></p>
            <p>Deployment Mode: <strong>{deployment_mode}</strong></p>
            <p><a href="{base_url}/getmyip">Check outbound IP address</a></p>
        </body>
        </html>
        """
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'text/html'},
            'body': html
        }
    
    elif path == '/getmyip' or path == f'/{stage}/getmyip':
        try:
            # Simple outbound request to fetch IP
            with urllib.request.urlopen('https://ifconfig.me/ip', timeout=5) as response:
                outbound_ip = response.read().decode('utf-8').strip()
            
            html = f"""
            <html>
            <head><title>AWS Private Connectivity Demo</title></head>
            <body style="font-family: Arial;">
                <h1>AWS Private Connectivity Demo</h1>
                <p>Outbound IP address: <strong>{outbound_ip}</strong></p>
                <p>Deployment Mode: <strong>{deployment_mode}</strong></p>
                <p><a href="{base_url}/">Back to home</a></p>
            </body>
            </html>
            """
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'text/html'},
                'body': html
            }
        except Exception as e:
            html = f"""
            <html>
            <head><title>AWS Private Connectivity Demo - Error</title></head>
            <body style="font-family: Arial;">
                <h1>AWS Private Connectivity Demo</h1>
                <p>Error checking outbound connectivity: <strong>{str(e)}</strong></p>
                <p>This might indicate restricted outbound access.</p>
                <p>Deployment Mode: <strong>{deployment_mode}</strong></p>
                <p><a href="{base_url}/">Back to home</a></p>
            </body>
            </html>
            """
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'text/html'},
                'body': html
            }
    
    # Default 404 response
    return {
        'statusCode': 404,
        'headers': {'Content-Type': 'text/html'},
        'body': f'<h1>404 Not Found</h1><p>Path: {path}</p>'
    }
EOF

# Create zip file with just the lambda_function.py
cd .build
zip -r ../${CODE_ZIP_NAME} lambda_function.py
cd ..
rm -rf .build

echo "Lambda code package created: ${CODE_ZIP_NAME}"

# Step 3: Upload to S3
echo "Uploading Lambda code to S3..."
aws s3 cp ${CODE_ZIP_NAME} s3://${S3_BUCKET_NAME}/

# Step 4: Create CloudFormation template with VPC infrastructure for PRIVATE mode
cat << "EOFMARKER" > simple-lambda-template.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'AWS Private Connectivity Demo with Lambda'

Parameters:
  CodeBucketName:
    Type: String
    Description: The S3 bucket containing the Lambda code
  
  CodeKey:
    Type: String
    Description: The S3 key for the Lambda code
  
  DeploymentMode:
    Type: String
    Default: PUBLIC
    AllowedValues:
      - PUBLIC
      - PRIVATE
    Description: Deploy in PUBLIC or PRIVATE mode

  LatestAmiId:
    Type: AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>
    Default: /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64
    Description: Latest Amazon Linux 2023 AMI ID

Conditions:
  DeployPrivate: !Equals [!Ref DeploymentMode, 'PRIVATE']

Resources:
  # VPC and Networking Resources (only created in PRIVATE mode)
  VPC:
    Type: AWS::EC2::VPC
    Condition: DeployPrivate
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: PrivateConnectivityDemoVPC

  PublicSubnet:
    Type: AWS::EC2::Subnet
    Condition: DeployPrivate
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.1.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: PublicSubnet

  PrivateSubnet:
    Type: AWS::EC2::Subnet
    Condition: DeployPrivate
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.2.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      MapPublicIpOnLaunch: false
      Tags:
        - Key: Name
          Value: PrivateSubnet

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Condition: DeployPrivate
    Properties:
      Tags:
        - Key: Name
          Value: PrivateConnectivityDemoIGW

  VPCGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Condition: DeployPrivate
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Condition: DeployPrivate
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: PublicRouteTable

  PublicRoute:
    Type: AWS::EC2::Route
    Condition: DeployPrivate
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  PublicSubnetRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Condition: DeployPrivate
    Properties:
      SubnetId: !Ref PublicSubnet
      RouteTableId: !Ref PublicRouteTable

  EIP:
    Type: AWS::EC2::EIP
    Condition: DeployPrivate
    Properties:
      Domain: vpc

  NATGateway:
    Type: AWS::EC2::NatGateway
    Condition: DeployPrivate
    Properties:
      AllocationId: !GetAtt EIP.AllocationId
      SubnetId: !Ref PublicSubnet
      Tags:
        - Key: Name
          Value: PrivateConnectivityDemoNAT

  PrivateRouteTable:
    Type: AWS::EC2::RouteTable
    Condition: DeployPrivate
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: PrivateRouteTable

  PrivateRoute:
    Type: AWS::EC2::Route
    Condition: DeployPrivate
    Properties:
      RouteTableId: !Ref PrivateRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NATGateway

  PrivateSubnetRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Condition: DeployPrivate
    Properties:
      SubnetId: !Ref PrivateSubnet
      RouteTableId: !Ref PrivateRouteTable

  # VPC Endpoints for Private Access
  ApiGatewayEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Condition: DeployPrivate
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub com.amazonaws.${AWS::Region}.execute-api
      VpcEndpointType: Interface
      PrivateDnsEnabled: true
      SubnetIds:
        - !Ref PrivateSubnet
      SecurityGroupIds:
        - !Ref VpcEndpointSecurityGroup

  VpcEndpointSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Condition: DeployPrivate
    Properties:
      GroupDescription: Security group for VPC endpoints
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 10.0.0.0/16
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0

  # Private API Gateway
  ApiGateway:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: !Sub connectivity-demo-api-${AWS::AccountId}
      EndpointConfiguration:
        Types:
          - !If [DeployPrivate, PRIVATE, REGIONAL]
        VpcEndpointIds: !If [DeployPrivate, [!Ref ApiGatewayEndpoint], !Ref AWS::NoValue]
      Policy: !If
        - DeployPrivate
        - !Sub |
          {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Allow",
                "Principal": "*",
                "Action": "execute-api:Invoke",
                "Resource": "execute-api:/*"
              },
              {
                "Effect": "Deny",
                "Principal": "*",
                "Action": "execute-api:Invoke",
                "Resource": "execute-api:/*",
                "Condition": {
                  "StringNotEquals": {
                    "aws:SourceVpce": "${ApiGatewayEndpoint}"
                  }
                }
              }
            ]
          }
        - !Ref AWS::NoValue

  # Test EC2 Instance in Private Subnet
  TestInstanceSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Condition: DeployPrivate
    Properties:
      GroupDescription: Security group for test instance
      VpcId: !Ref VPC
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0

  TestInstance:
    Type: AWS::EC2::Instance
    Condition: DeployPrivate
    Properties:
      ImageId: !Ref LatestAmiId
      InstanceType: t3.micro
      SubnetId: !Ref PrivateSubnet
      SecurityGroupIds:
        - !Ref TestInstanceSecurityGroup
      IamInstanceProfile: !Ref TestInstanceProfile
      Tags:
        - Key: Name
          Value: PrivateConnectivityTestInstance

  TestInstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Condition: DeployPrivate
    Properties:
      Roles:
        - !Ref TestInstanceRole

  TestInstanceRole:
    Type: AWS::IAM::Role
    Condition: DeployPrivate
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

  # Proxy Resource
  ProxyResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref ApiGateway
      ParentId: !GetAtt ApiGateway.RootResourceId
      PathPart: '{proxy+}'

  # Root Method
  RootMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref ApiGateway
      ResourceId: !GetAtt ApiGateway.RootResourceId
      HttpMethod: ANY
      AuthorizationType: NONE
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${ConnectivityFunction.Arn}/invocations

  # Proxy Method
  ProxyMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref ApiGateway
      ResourceId: !Ref ProxyResource
      HttpMethod: ANY
      AuthorizationType: NONE
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${ConnectivityFunction.Arn}/invocations

  # Deployment
  ApiDeployment:
    Type: AWS::ApiGateway::Deployment
    DependsOn:
      - RootMethod
      - ProxyMethod
    Properties:
      RestApiId: !Ref ApiGateway
      StageName: prod

  # Lambda Execution Role
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - 'arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'
        - !If 
          - DeployPrivate
          - 'arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole'
          - !Ref AWS::NoValue

  # Lambda Function
  ConnectivityFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub connectivity-demo-${AWS::AccountId}
      Handler: lambda_function.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        S3Bucket: !Ref CodeBucketName
        S3Key: !Ref CodeKey
      Runtime: python3.9
      Timeout: 10
      MemorySize: 128
      Environment:
        Variables:
          DEPLOYMENT_MODE: !Ref DeploymentMode
      VpcConfig: !If
        - DeployPrivate
        - SubnetIds:
            - !Ref PrivateSubnet
          SecurityGroupIds:
            - !Ref LambdaSecurityGroup
        - !Ref AWS::NoValue

  LambdaSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Condition: DeployPrivate
    Properties:
      GroupDescription: Security group for Lambda function
      VpcId: !Ref VPC
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0

  # Lambda Permission for API Gateway
  LambdaApiPermission:
    Type: AWS::Lambda::Permission
    Properties:
      Action: lambda:InvokeFunction
      FunctionName: !Ref ConnectivityFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${ApiGateway}/*/*/*

Outputs:
  ApiUrl:
    Description: URL of the API Gateway endpoint
    Value: !Sub https://${ApiGateway}.execute-api.${AWS::Region}.amazonaws.com/prod/
  
  TestInstanceId:
    Description: ID of the test EC2 instance
    Value: !If 
      - DeployPrivate
      - !Ref TestInstance
      - "Not applicable in PUBLIC mode"
  
  VpcId:
    Description: ID of the VPC
    Value: !If 
      - DeployPrivate
      - !Ref VPC
      - "Not applicable in PUBLIC mode"
  
  PrivateSubnetId:
    Description: ID of the private subnet
    Value: !If 
      - DeployPrivate
      - !Ref PrivateSubnet
      - "Not applicable in PUBLIC mode"
EOFMARKER

# Step 5: Deploy CloudFormation stack
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
  --stack-name ${STACK_NAME} \
  --template-file simple-lambda-template.yaml \
  --parameter-overrides \
    CodeBucketName=${S3_BUCKET_NAME} \
    CodeKey=${CODE_ZIP_NAME} \
    DeploymentMode=${DEPLOYMENT_MODE} \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset

# Step 7: Get deployment outputs
echo "Fetching deployment outputs..."
API_URL=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text)

if [[ "$DEPLOYMENT_MODE" == "PRIVATE" ]]; then
  TEST_INSTANCE_ID=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='TestInstanceId'].OutputValue" --output text)
  VPC_ID=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" --output text)
  PRIVATE_SUBNET_ID=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='PrivateSubnetId'].OutputValue" --output text)
fi

echo ""
echo "=== Deployment Complete ==="
echo "Deployment Mode: ${DEPLOYMENT_MODE}"
echo "API URL: ${API_URL}"

if [[ "$DEPLOYMENT_MODE" == "PRIVATE" ]]; then
  echo ""
  echo "=== Private Mode Details ==="
  echo "Test Instance ID: ${TEST_INSTANCE_ID}"
  echo "VPC ID: ${VPC_ID}"
  echo "Private Subnet ID: ${PRIVATE_SUBNET_ID}"
  echo ""
  echo "To test the private setup:"
  echo "1. Connect to the test instance using Session Manager:"
  echo "   aws ssm start-session --target ${TEST_INSTANCE_ID}"
  echo "2. From the test instance, try accessing the API:"
  echo "   curl ${API_URL}"
  echo "3. The API should be accessible only from within the VPC"
  echo "4. Try accessing the API from your local machine - it should fail"
else
  echo ""
  echo "To demonstrate private connectivity:"
  echo "1. Access the API via the URL to see public access behavior"
  echo "2. Redeploy in PRIVATE mode: ./deploy-lambda.sh PRIVATE"
  echo "3. Compare the outbound IP addresses - in PRIVATE mode, the IP will be your VPC's NAT Gateway IP"
fi

# Clean up temporary files
rm -f simple-lambda-template.yaml ${CODE_ZIP_NAME} 