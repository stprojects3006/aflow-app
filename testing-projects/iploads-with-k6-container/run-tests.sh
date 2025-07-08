
echo "[DEBUG] PWD: $(pwd)"
echo "[DEBUG] SCRIPT: $0"
echo "[DEBUG] ECS_CLUSTER_NAME: $ECS_CLUSTER_NAME"
echo "[DEBUG] SUBNET_ID: $SUBNET_ID"
echo "[DEBUG] SECURITY_GROUP_ID: $SECURITY_GROUP_ID"
echo "ECS_CLUSTER_NAME=$ECS_CLUSTER_NAME"
echo "SUBNET_ID=$SUBNET_ID"
echo "SECURITY_GROUP_ID=$SECURITY_GROUP_ID"
echo aws ecs run-task \
    --cluster "$ECS_CLUSTER_NAME" \
    --task-definition arn:aws:ecs:us-east-1:786407478307:task-definition/k6-load-test-k6-task:2 \
    --launch-type FARGATE \
    --network-configuration 'awsvpcConfiguration={subnets=["'$SUBNET_ID'"],securityGroups=["'$SECURITY_GROUP_ID'"],assignPublicIp="ENABLED"}' \
    --overrides '{"containerOverrides":[{"name":"k6-load-test","environment":[{"name":"TEST_TYPE","value":"basic"}]}]}' \
    --query 'tasks[0].taskArn' \
    --output text

TASK_ARN=$(aws ecs run-task \
    --cluster "$ECS_CLUSTER_NAME" \
    --task-definition arn:aws:ecs:us-east-1:786407478307:task-definition/k6-load-test-k6-task:2 \
    --launch-type FARGATE \
    --network-configuration 'awsvpcConfiguration={subnets=["'$SUBNET_ID'"],securityGroups=["'$SECURITY_GROUP_ID'"],assignPublicIp="ENABLED"}' \
    --overrides '{"containerOverrides":[{"name":"k6-load-test","environment":[{"name":"TEST_TYPE","value":"basic"}]}]}' \
    --query 'tasks[0].taskArn' \
    --output text) 