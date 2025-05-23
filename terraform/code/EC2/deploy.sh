#!/bin/bash
set -e

echo "🚀 Starting EC2 deployment"

# ==== Config ====
AWS_REGION=${AWS_REGION:-us-east-2}
TF_STATE_BUCKET=${TF_STATE_BUCKET:-vj-test-benvolate}
EC2_TFSTATE_KEY="EC2/terraform.tfstate"
ZIP_NAME="nodejs-app.zip"
ZIP_S3_KEY="nodejs/nodejs-app.zip"

# ==== Validate App ====
echo "🔍 Verifying application source..."
grep 'Hello' Nodejs/index.js

# ==== Zip App ====
echo "📦 Zipping Node.js app..."
rm -f $ZIP_NAME
cd Nodejs
zip -r ../$ZIP_NAME .
cd ..
ls -lh $ZIP_NAME

# ==== Upload to S3 ====
echo "☁️ Uploading files to S3..."
aws s3 cp $ZIP_NAME s3://$TF_STATE_BUCKET/$ZIP_S3_KEY --region $AWS_REGION
aws s3 cp scripts/node-deploy.sh s3://$TF_STATE_BUCKET/scripts/node-deploy.sh --region $AWS_REGION

# ==== Terraform EC2 ====
echo "📐 Terraform Init & Apply for EC2..."
cd terraform/code/EC2
terraform init \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="key=$EC2_TFSTATE_KEY" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="encrypt=true"

terraform plan -input=false -out=tfplan
# terraform apply -auto-approve tfplan


# === Destroy resources ===
terraform destroy -auto-approve


# cd ../../..

# # ==== Extract EC2 Instance IDs ====
# echo "🔍 Extracting EC2 instance IDs..."
# aws s3 cp s3://$TF_STATE_BUCKET/$EC2_TFSTATE_KEY tfstate.json --region $AWS_REGION

# INSTANCE_IDS=$(jq -r '.resources[] | select(.type == "aws_instance") | .instances[].attributes.id' tfstate.json 2>/dev/null || echo "")
# if [ -z "$INSTANCE_IDS" ]; then
#   echo "❌ No EC2 instance IDs found."
#   exit 1
# fi

# echo "✅ Found EC2 instance IDs: $INSTANCE_IDS"
# sleep 60  # Let EC2s fully boot and SSM agent initialize

# # ==== Deploy App via SSM ====
# echo "🚀 Deploying Node.js app on EC2s..."
# for INSTANCE_ID in $INSTANCE_IDS; do
#   echo "👉 Deploying to $INSTANCE_ID"

#   CMD_ID=$(aws ssm send-command \
#     --instance-ids "$INSTANCE_ID" \
#     --document-name "AWS-RunShellScript" \
#     --parameters 'commands=[
#       "curl -o /tmp/node-deploy.sh https://'"$TF_STATE_BUCKET"'.s3.'"$AWS_REGION"'.amazonaws.com/scripts/node-deploy.sh",
#       "chmod +x /tmp/node-deploy.sh",
#       "bash /tmp/node-deploy.sh"
#     ]' \
#     --region $AWS_REGION \
#     --query "Command.CommandId" \
#     --output text)

#   echo "✅ Command sent to $INSTANCE_ID: $CMD_ID"

#   for i in {1..30}; do
#     STATUS=$(aws ssm get-command-invocation \
#       --command-id "$CMD_ID" \
#       --instance-id "$INSTANCE_ID" \
#       --region "$AWS_REGION" \
#       --query "Status" \
#       --output text 2>/dev/null || echo "Pending")

#     echo "Status on $INSTANCE_ID: $STATUS"

#     if [[ "$STATUS" == "Success" ]]; then
#       echo "✅ Deployment succeeded on $INSTANCE_ID"
#       break
#     elif [[ "$STATUS" == "Failed" ]]; then
#       echo "❌ Deployment failed on $INSTANCE_ID"
#       break
#     fi
#     sleep 10
#   done
# done

# # ==== Configure NGINX ====
# echo "⚙️ Configuring NGINX on EC2s..."
# for INSTANCE_ID in $INSTANCE_IDS; do
#   echo "Configuring NGINX on $INSTANCE_ID"

#   CMD_ID=$(aws ssm send-command \
#     --instance-ids "$INSTANCE_ID" \
#     --document-name "AWS-RunShellScript" \
#     --parameters 'commands=[
#       "sudo yum install -y nginx",
#       "sudo systemctl enable nginx",
#       "sudo systemctl start nginx",
#       "sudo bash -c \"cat > /etc/nginx/conf.d/nodeapp.conf <<'\''CONFIG'\''\nserver {\n  listen 80;\n  server_name _;\n  location / {\n    proxy_pass http://localhost:3000;\n    proxy_http_version 1.1;\n    proxy_set_header Upgrade \$http_upgrade;\n    proxy_set_header Connection '\''upgrade'\'';\n    proxy_set_header Host \$host;\n    proxy_cache_bypass \$http_upgrade;\n  }\n}\nCONFIG\"",
#       "sudo rm -f /etc/nginx/conf.d/default.conf",
#       "sudo nginx -t && sudo systemctl reload nginx"
#     ]' \
#     --region "$AWS_REGION" \
#     --query "Command.CommandId" \
#     --output text)
  
#   for i in {1..10}; do
#     STATUS=$(aws ssm get-command-invocation \
#       --command-id "$CMD_ID" \
#       --instance-id "$INSTANCE_ID" \
#       --region "$AWS_REGION" \
#       --query "Status" \
#       --output text 2>/dev/null || echo "Pending")

#     echo "Nginx status on $INSTANCE_ID: $STATUS"

#     if [[ "$STATUS" == "Success" ]]; then
#       echo "✅ NGINX configured on $INSTANCE_ID"
#       break
#     elif [[ "$STATUS" == "Failed" ]]; then
#       echo "❌ NGINX config failed on $INSTANCE_ID"
#       break
#     fi
#     sleep 5
#   done
# done

# # ==== Summary ====
# echo "====== Deployment Summary ======"
# echo "Total EC2 instances processed: $(echo $INSTANCE_IDS | wc -w)"
# echo "Deployed Node.js app to all instances"
# echo "Configured NGINX as reverse proxy"
# echo "✅ Done"
# echo "================================"
