#!/bin/bash

# This script can be used to manually update the k8s secrets when needed.

set -e
cd "$( dirname "${BASH_SOURCE[0]}" )"

echo "Select Environment"
options=("dev" "prod")
select opt in "${options[@]}"
do
  tput sgr0
  case $opt in
    "dev")
      ENV='dev'
      gcloud config set project newscorp-newsiq-dev
      if [[ ! -e .secrets-repo-dev ]]; then
        git clone keybase://team/prebid.dev/secrets .secrets-repo-dev
      else
        pushd .secrets-repo-dev
        git pull
        popd
      fi
      break
      ;;
    "prod")
      ENV='prod'
      gcloud config set project newscorp-newsiq
      if [[ ! -e .secrets-repo-prod ]]; then
        git clone keybase://team/prebid.prod/secrets .secrets-repo-prod
      else
        pushd .secrets-repo-prod
        git pull
        popd
      fi
      break
      ;;
    *) echo invalid option;;
  esac
done

gcloud config set container/cluster  kubernetes-prebid-cloudops
gcloud container clusters get-credentials kubernetes-prebid-cloudops --zone us-east1-c

echo "Update prebid-environment..."

kubectl --namespace=prebid create secret generic prebid-environment \
    --from-file=environment=.secrets-repo-${ENV}/others/environment \
    --dry-run -o yaml | kubectl apply -f -

echo "Update grafana-config-ini"

kubectl --namespace=monitoring create secret generic grafana-config-ini \
    --from-file=smtp-user=.secrets-repo-${ENV}/others/smtp_user \
    --from-file=smtp-password=.secrets-repo-${ENV}/others/smtp_password \
    --from-file=smtp-host=.secrets-repo-${ENV}/others/smtp_host \
    --from-file=smtp-port=.secrets-repo-${ENV}/others/smtp_port \
    --from-file=from-email=.secrets-repo-${ENV}/others/from_email \
    --from-file=grafana_url=.secrets-repo-${ENV}/others/grafana_url \
    --dry-run -o yaml | kubectl apply -f -

echo "Update prebid-secrets..."

kubectl --namespace=prebid create secret generic prebid-secrets \
    --from-file=project-name=.secrets-repo-${ENV}/kubernetes/project_name \
    --from-file=prebid-service-account=.secrets-repo-${ENV}/kubernetes/prebid-server_service_account.json \
    --from-file=prebid_cache_host=.secrets-repo-${ENV}/kubernetes/prebid_cache_host \
    --from-file=prebid_cache_port=.secrets-repo-${ENV}/kubernetes/prebid_cache_port \
    --from-file=prebid_cache_endpoint=.secrets-repo-${ENV}/kubernetes/prebid_cache_endpoint \
    --dry-run -o yaml | kubectl apply -f -    
    --dry-run -o yaml | kubectl apply -f -  

echo "Update influxdb-secrets..."

kubectl --namespace=prebid create secret generic influxdb-secrets \
    --from-file=database=.secrets-repo-${ENV}/influxdb/database \
    --from-file=db_admin_password=.secrets-repo-${ENV}/influxdb/db_admin_password \
    --from-file=db_admin_username=.secrets-repo-${ENV}/influxdb/db_admin_username \
    --from-file=db_prebid_password=.secrets-repo-${ENV}/influxdb/db_prebid_password \
    --from-file=db_prebid_username=.secrets-repo-${ENV}/influxdb/db_prebid_username \
    --dry-run -o yaml | kubectl apply -f -   

echo "Done."