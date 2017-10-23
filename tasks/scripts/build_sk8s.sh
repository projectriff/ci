#!/bin/bash

set -exuo pipefail

build_root=$PWD

model_dir="$(go env GOPATH)/src/github.com/fabric8io"
mkdir -p $model_dir
cp -r $build_root/git-kubernetes-model $model_dir/kubernetes-model
cd $model_dir/kubernetes-model

#export MAVEN_OPTS="-Xms512m -Xmx1024m -XX:MetaspaceSize=512M -XX:MaxMetaspaceSize=1024M -XX:MaxPermSize=128m -XX:+CMSClassUnloadingEnabled -XX:+UseConcMarkSweepGC"
export MAVEN_OPTS="-XX:-UseGCOverheadLimit -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/root"

make
cd $build_root/git-sk8s


set +u
source /opt/resource/common.sh
start_docker # starting docker here instead of at the beginning, due to memory restrictions

./mvnw clean package
./dockerize
set -u

mkdir ~/.kube
echo "$KUBECONFIG_STRING" > ~/.kube/config

set +e
existing_ns=$(kubectl get ns -o json | jq -r  .items[].metadata.name | grep "$K8S_NS_PREFIX")

if [ ! -z "$existing_ns" ]; then
  kubectl delete ns "$existing_ns" --cascade=true
  sleep 30
fi
set -e

ns_suffix=$(date "+%s")
ns_name="$K8S_NS_PREFIX"-"$ns_suffix"

kubectl create ns "$ns_name"
kubectl apply -f config/types -n "$ns_name"
kubectl apply -f config/kafka -n "$ns_name"
kubectl apply -f config -n "$ns_name"

cp $build_root/git-sk8s/function-invokers/java-function-invoker/target/java-function-invoker*.jar "$build_root/sk8s-invoker-java/"
