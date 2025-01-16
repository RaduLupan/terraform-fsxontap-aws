{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "SSMAccess",
        "Action": [
          "ssm:Get*",
          "ssm:Describe*",
          "ssm:List*",
          "ssm:PutParam*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      },
      {
        "Sid": "S3Access",
        "Action": [
          "s3:GetObject"
        ],
        "Effect": "Allow",
        "Resource": "*"
      },
      {
        "Sid": "CWLogsAccess",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }