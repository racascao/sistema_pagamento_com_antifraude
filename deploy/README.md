# Deploy no GCP

Este documento explica como colocar o sistema pra rodar num cluster GKE real.

Pré-requisitos:
- Conta no Google Cloud com faturamento ativado
- gcloud instalado e autenticado (`gcloud auth login`)
- kubectl instalado
- Docker instalado
- Terraform instalado

Aviso: os passos abaixo criam recursos reais na nuvem e geram custo. Lembre de rodar o passo de destruição no final quando terminar de usar.

## 1. Ativar as APIs necessárias

```
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  sqladmin.googleapis.com \
  servicenetworking.googleapis.com \
  managedkafka.googleapis.com \
  artifactregistry.googleapis.com \
  monitoring.googleapis.com \
  --project SEU_PROJECT_ID
```

## 2. Criar a infraestrutura com Terraform

```
cd deploy/terraform
terraform init
terraform apply \
  -var="project_id=SEU_PROJECT_ID" \
  -var="region=us-central1" \
  -var="db_password=UMA_SENHA_FORTE"
```

Guarde a senha que você escolheu, ela vai ser usada no passo 5.

Ao final, veja os dados gerados:

```
terraform output
```

## 3. Conectar o kubectl ao cluster criado

```
gcloud container clusters get-credentials payment-processor \
  --region us-central1 \
  --project SEU_PROJECT_ID
```

## 4. Buildar e publicar as imagens

```
gcloud auth configure-docker us-central1-docker.pkg.dev

deploy/scripts/push-images.sh SEU_PROJECT_ID us-central1 v1
```

Esse script builda as imagens do gateway, ledger, investigator, console e fraud, e publica no Artifact Registry criado pelo Terraform.

## 5. Criar o Secret do banco e o ConfigMap do Kafka

```
DB_IP=$(cd deploy/terraform && terraform output -raw ledger_db_private_ip)
KAFKA_BOOTSTRAP=$(cd deploy/terraform && terraform output -raw kafka_bootstrap)

kubectl create namespace payment-processor

kubectl -n payment-processor create secret generic ledger-database \
  --from-literal=url="postgres://postgres:UMA_SENHA_FORTE@${DB_IP}:5432/payments?sslmode=require"

kubectl -n payment-processor create configmap kafka-config \
  --from-literal=broker="$KAFKA_BOOTSTRAP"
```

Use a mesma senha que você definiu no passo 2.

## 6. Aplicar os manifests da aplicação

```
make gcp-deploy GCP_PROJECT=SEU_PROJECT_ID
```

## 7. Verificar se está tudo rodando

```
kubectl get pods -n payment-processor
```

Todos os pods devem ficar com status Running e 0 reinícios.

Para testar a API, abra um túnel local:

```
kubectl port-forward -n payment-processor svc/gateway 18080:8080
```

E em outro terminal:

```
curl -X POST http://localhost:18080/v1/payments \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: teste-1" \
  -d '{"account_id":"00000000-0000-0000-0000-000000000002","card_fingerprint":"fp_teste","amount_cents":5000,"currency":"BRL","merchant_category":"electronics"}'
```

## 8. Ver as métricas

As métricas ficam disponíveis no Cloud Monitoring, na seção Metrics Explorer, usando PromQL.

Exemplo de consulta:

```
ledger_decisions_total
```

## 9. Destruir tudo quando terminar

```
cd deploy/terraform
terraform destroy \
  -var="project_id=SEU_PROJECT_ID" \
  -var="region=us-central1" \
  -var="db_password=UMA_SENHA_FORTE"
```

Se aparecer um erro dizendo que o banco não pode ser apagado por causa de proteção contra exclusão, rode primeiro:

```
terraform apply -target=google_sql_database_instance.ledger \
  -var="project_id=SEU_PROJECT_ID" \
  -var="region=us-central1" \
  -var="db_password=UMA_SENHA_FORTE"
```

Depois de mudar `deletion_protection` para `false` no arquivo `database.tf`, e então rode o comando de destroy novamente.

Se der um erro sobre a conexão de rede ainda estar em uso, espere alguns minutos e rode o comando de destroy de novo. É uma demora normal do lado do Google depois de apagar o banco.
