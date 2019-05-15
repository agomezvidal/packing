APPLICATION      ?= component1
export ENV     ?= prod
SERVICE        ?= web
TF_PROVIDER    := aws
TF_FOLDER      := ./ops/terraform/${TF_PROVIDER}/${ENV}
TF_LOCK_FOLDER := ./ops/terraform/${TF_PROVIDER}/lock/${ENV}
TF_PLAN_FILE   := plan.out
# Amazon Linux HVM SSD EBS - see packer filter
DEFAULT_AMI    ?= ami-0080e4c5bc078760e
AWS_REGION     ?= us-east-1
AWS_USER       ?= ec2-user
export AWS_PROFILE = default

all: bootstrap dev logs

packer:
	docker run  -ti -v ~/.aws:/root/.aws -v ${PWD}:/app --entrypoint /bin/sh hashicorp/packer:full

bootstrap:
	@./scripts/docker-bootstrap.sh

dev:
	@docker-compose -p ${APPLICATION} -f dockeryml/docker-compose.yml up -d

enter:
	@./scripts/docker-enter.sh ${APPLICATION}

nodev: kill
	@docker-compose -p ${APPLICATION} -f dockeryml/docker-compose.yml rm -f
	@for i in `docker network ls | grep ${APPLICATION}_vpcbr | cut -f1 -d ' '`; do \
		echo "Removing network ${APPLICATION}_vpcbr ... " \
		&& docker network rm $$i \
		&& echo "Done" \
	; done

kill:
	@docker-compose -p ${APPLICATION} -f dockeryml/docker-compose.yml kill

log: logs
logs:
	@docker-compose -p ${APPLICATION} -f dockeryml/docker-compose.yml logs -f

deps: init
	cd ${TF_FOLDER} && terraform get

deps-lock: init-lock
	cd ${TF_LOCK_FOLDER} && terraform get

init:
	@if [ -d "${TF_FOLDER}/.terraform" ]; then \
		echo "Loading current backend configuration"; \
	else echo "No backend configured, loading:"; \
	  cd ${TF_FOLDER} && terraform init; \
	fi

init-lock:
	@if [ -d "${TF_LOCK_FOLDER}/.terraform" ]; then \
		echo "Loading current Lock state configuration"; \
	else echo "No backend configured for Lock plan, loading:"; \
	  cd ${TF_LOCK_FOLDER} && terraform init; \
	fi

validate:
	@cd ${TF_FOLDER} && terraform validate

lock-state-plan: init-lock deps-lock
	@cd ${TF_LOCK_FOLDER} && terraform plan -parallelism=50 -out=${TF_PLAN_FILE}

lock-state-apply: init-lock
	@cd ${TF_LOCK_FOLDER} && [ -f ${TF_PLAN_FILE} ] \
		&& terraform apply -paralelism=50  ${TF_PLAN_FILE} && rm -f ${TF_PLAN_FILE} \
		|| (echo "[ERROR]: Plan doesn't exist or debug error output" ; exit 1)

${TF_FOLDER}/%.tf.template: ${TF_FOLDER}
	@./ops/scripts/generate-aws-certs.sh $< $@

${TF_FOLDER}/%.tf.json: ${TF_FOLDER}/%.list
	@./ops/scripts/gen_tf.py $< $@

plan: ${TF_FOLDER}/domains.tf.json init deps validate
	@cd ${TF_FOLDER} && terraform plan -out=${TF_PLAN_FILE}

apply: validate
	@cd ${TF_FOLDER} && [ -f ${TF_PLAN_FILE} ] \
		&& terraform apply ${TF_PLAN_FILE} && rm -f ${TF_PLAN_FILE} \
		|| (echo "[ERROR]: Plan doesn't exist or debug error output" ; exit 1)

local-packer:
	# Load var file only if it's needed or other values 
	@echo "Using default variables ..."
	packer build \
		--var="environ=${ENV}" \
		--var="application=${APPLICATION}" \
		--var="service=${SERVICE}" \
		--var="region=${AWS_REGION}" \
		--var="ami-id=${DEFAULT_AMI}" \
		--var="aws-user=${AWS_USER}" \
		packeryml/config.json
